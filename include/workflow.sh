#!/bin/bash
# fw-generate script to be included.

unload_workflow_sh() {
  unset load_workflow
  unset create_workflow
  unset create_workflow_nodes
  unset prepare_workflow_item
  unset unload_workflow_sh
}

load_workflow() {
  local object=
  local task=
  local id=
  local existing=
  local -i i=0
  local -i j=0
  local -i failure=0

  workflow_objects=$(fss_basic_list_read -oq $workflow_file)
  workflow_objects_settings=

  for object in $workflow_objects ; do
    if [[ $object == "settings" || $(echo -n $object | grep -sPo "settings\.[\w+-]+") != "" ]] ; then
      workflow_objects_settings="$workflow_objects_settings$object "
    fi
  done

  let tasks_total=$(fss_basic_list_read -cqn tasks $workflow_file | fss_extended_read -tq)

  if [[ $tasks_total -eq 0 ]] ; then
    echo_error_out "The workflow '$c_n$workflow$c_e' does not have any tasks."

    return 1
  fi

  # create start task.
  existing=$(fss_basic_list_read -cqn tasks $workflow_file | fss_extended_read -oqnt startEvent)

  if [[ $? -ne 0 ]] ; then
    echo_error_out "Failed to read the workflow '$c_n$workflow$c_e'."

    return 1
  fi

  if [[ $existing -eq 0 ]] ; then
    let j=1

    tasks_task["0"]="startEvent"
    tasks_machine["0"]="start"
    tasks_human["0"]="Start"
    task=${tasks_machine["0"]}

    id=$(fss_basic_list_read -cqn ${tasks_machine["0"]} $workflow_file | fss_basic_read -cqns id 0)

    if [[ $? -ne 0 ]] ; then
      echo_error_out "Failed to read the (optional) '{c_n}id$c_e' tasks Object (for $task) from the workflow '$c_n$workflow$c_e'."

      return 1
    fi

    if [[ $id == "" ]] ; then
      id=$(uuidgen -r)
    fi

    tasks_uuid["0"]=$id
  fi

  # create tasks.
  while [[ $i -lt $tasks_total ]] ; do
    tasks_task["$j"]=$(fss_basic_list_read -cqn tasks $workflow_file | fss_extended_read -oqa $i)
    if [[ $? -ne 0 ]] ; then let failure=1 ; break ; fi

    tasks_machine["$j"]=$(fss_basic_list_read -cqn tasks $workflow_file | fss_extended_read -cqas $i 0)
    if [[ $? -ne 0 ]] ; then let failure=1 ; break ; fi

    tasks_human["$j"]=$(fss_basic_list_read -cqn tasks $workflow_file | fss_extended_read -cqas $i 1)
    if [[ $? -ne 0 ]] ; then let failure=1 ; break ; fi

    id=$(fss_basic_list_read -cqn tasks $workflow_file | fss_extended_read -cqas $i 2)
    if [[ $? -ne 0 ]] ; then let failure=1 ; break ; fi

    task=${tasks_machine["$j"]}

    if [[ $id == "" ]] ; then
      id=$(fss_basic_list_read -cqn ${tasks_machine["$j"]} $workflow_file | fss_basic_read -cqns id 0)

      if [[ $? -ne 0 ]] ; then
        echo_error_out "Failed to read the (optional) '{c_n}id$c_e' tasks Object (for $task) from the workflow '$c_n$workflow$c_e'."

        return 1
      fi
    fi

    if [[ $id == "" ]] ; then
      id=$(uuidgen -r)
    fi

    tasks_uuid["$j"]="$id"

    check_exists_already "$directory_generated${task}.json" "generated workflow"
    if [[ $? -ne 0 ]] ; then return 1 ; fi

    let i++
    let j++
  done

  if [[ $failure -ne 0 ]] ; then
    echo_error_out "Failed to read the tasks Object from the workflow '$c_n$workflow$c_e'."

    return 1
  fi

  # if the startEvent has been automatically added, then increment before reusing the "existing" variable.
  if [[ $existing -eq 0 ]] ; then
    let tasks_total++
  fi

  # create stop task.
  existing=$(fss_basic_list_read -cqn tasks $workflow_file | fss_extended_read -oqnt endEvent)

  if [[ $? -ne 0 ]] ; then
    echo_error_out "Failed to read the workflow '$c_n$workflow$c_e'."

    return 1
  fi

  if [[ $existing -eq 0 ]] ; then
    tasks_task["$j"]="endEvent"
    tasks_machine["$j"]="end"
    tasks_human["$j"]="End"
    task=${tasks_machine["$j"]}

    id=$(fss_basic_list_read -cqn ${tasks_machine["$j"]} $workflow_file | fss_basic_read -cqns id 0)

    if [[ $? -ne 0 ]] ; then
      echo_error_out "Failed to read the (optional) '{c_n}id$c_e' tasks Object (for $task) from the workflow '$c_n$workflow$c_e'."

      return 1
    fi

    if [[ $id == "" ]] ; then
      id=$(uuidgen -r)
    fi

    tasks_uuid["$j"]=$id

    # increment to account for endEvent.
    let tasks_total++
  fi

  return 0
}

create_workflow() {
  local processed="id name nodes "
  local -a properties=()
  local -a values=()
  local -a depths=()
  local -i total=0
  local -i i=0
  local -i j=0
  local -i lines=
  local id=
  local machine=
  local name=
  local map=
  local data=
  local type=
  local object=
  local ignore=

  # ID, if supplied is used, otherwise is generated.
  id=$(fss_basic_list_read -cqn settings $workflow_file | fss_basic_read -cqns id 0)

  if [[ $? -ne 0 ]] ; then
    echo_error_out "Failed to read the (optional) '{c_n}id$c_e' settings Object from the workflow '$c_n$workflow$c_e'."

    return 1
  fi

  if [[ $id == "" ]] ; then
    id=$(uuidgen -r)
  fi

  # The name, if supplied is used, otherwise is created from the name given on the program input.
  name=$(fss_basic_list_read -cqn settings $workflow_file | fss_basic_read -cqns name 0)

  if [[ $? -ne 0 ]] ; then
    echo_error_out "Failed to read the (optional) '{c_n}name$c_e' settings Object from the workflow '$c_n$workflow$c_e'."

    return 1
  fi

  if [[ $name == "" ]] ; then
    name=$workflow
  fi

  echo_out "Generating Workflow: $id, \"$name\""

  prepare_json_line 0 "id" "$id"
  prepare_json_line 0 "name" "$name"

  load_template_task "workflow" "settings"
  if [[ $? -ne 0 ]] ; then return 1 ; fi

  # Nodes are generated and are not loaded from the workflow template.
  prepare_json_line -1 "nodes" "array"

  let i=0
  while [[ $i -lt $tasks_total ]] ; do
    id=${tasks_uuid["$i"]}
    type=${tasks_task["$i"]}

    prepare_json_line -2 "" "{{mod-workflow}}/$type/$id"
    if [[ $? -ne 0 ]] ; then return 1 ; fi

    let i++
  done

  prepare_json_line_array_or_map_end -1 "array"

  write_json_file "${directory_generated}workflow.json"
  if [[ $? -ne 0 ]] ; then return 1 ; fi

  create_workflow_nodes
  if [[ $? -ne 0 ]] ; then return 1 ; fi

  if [[ ! -f "${directory_generated}setup.json" ]] ; then
    echo "{}" > "${directory_generated}setup.json"

    if [[ $? -ne 0 ]] ; then
      echo_error_out "Failed to create the setup JSON file: '$c_n${directory_generated}setup.json$c_e'."
      return 1
    fi
  fi

  data=$(fss_basic_list_read -oqnt triggers $workflow_file)

  if [[ $? -ne 0 ]] ; then
    echo_error_out "Failed to read the workflow file: '$c_n$workflow_file$c_e'."
    return 1
  fi

  if [[ $data -gt 0 && ! -d "${directory_generated}triggers" ]] ; then
    mkdir "${directory_generated}triggers"

    if [[ $? -ne 0 ]] ; then
      echo_error_out "Failed to create the triggers directory: '$c_n${directory_generated}triggers$c_e'."
      return 1
    fi

    prepare_workflow_triggers
    if [[ $? -ne 0 ]] ; then return 1 ; fi
  fi

  return 0
}

create_workflow_nodes() {
  local -i i=0
  local id=
  local type=
  local machine=
  local name=

  while [[ $i -lt $tasks_total ]] ; do
    local -a properties=()
    local -a values=()
    local -a depths=()
    let total=0

    id=${tasks_uuid["$i"]}
    type=${tasks_task["$i"]}
    machine=${tasks_machine["$i"]}
    name=${tasks_human["$i"]}

    check_exists_already "${directory_generated}nodes/${machine}.json" "generated node"
    if [[ $? -ne 0 ]] ; then return 1 ; fi

    prepare_workflow_item "$id" "$type" "$machine" "$name" "$workflow_file"
    if [[ $? -ne 0 ]] ; then return 1 ; fi

    write_json_file "${directory_generated}nodes/$machine.json"
    if [[ $? -ne 0 ]] ; then return 1 ; fi

    let i++
  done
}

# Arguments:
#   1) The ID (UUID).
#   2) The type.
#   3) The machine name.
#   4) The human name.
#
prepare_workflow_item() {
  local id="$1"
  local type="$2"
  local machine="$3"
  local name="$4"

  echo_out "Generating Item: $id, $type, $machine, \"$name\""

  prepare_json_line 0 "id" "$id"
  prepare_json_line 0 "name" "$name"

  load_template_task "$type" "$machine"
  if [[ $? -ne 0 ]] ; then return 1 ; fi

  return 0
}

# Arguments:
#   1) All of the triggers as loaded from fss_basic_list.
prepare_workflow_triggers() {
  local triggers="$1"
  local id=
  local type=
  local machine=
  local name=
  local -i lines=
  local -i failure=0
  local -i i=0

  lines=$(fss_basic_list_read -cqn triggers $workflow_file | fss_extended_read -oqt)
  failure=$?

  while [[ $i -lt $lines && $failure -eq 0 ]] ; do
    local -a properties=()
    local -a values=()
    local -a depths=()
    local -i total=0

    type=$(fss_basic_list_read -cqn triggers $workflow_file | fss_extended_read -oqea $i)
    failure=$?

    if [[ $failure -eq 0 ]] ; then
      machine=$(fss_basic_list_read -cqn triggers $workflow_file | fss_extended_read -cqaes $i 0)
      failure=$?
    fi

    if [[ $failure -eq 0 ]] ; then
      name=$(fss_basic_list_read -cqn triggers $workflow_file | fss_extended_read -cqaes $i 1)
      failure=$?
    fi

    if [[ $failure -eq 0 ]] ; then
      check_exists_already "${directory_generated}triggers/${machine}.json" "generated trigger"
      if [[ $? -ne 0 ]] ; then return 1 ; fi

      # ID, if supplied is used, otherwise is generated.
      id=$(fss_basic_list_read -cqn $machine $workflow_file | fss_basic_read -cqns id 0)

      if [[ $? -ne 0 ]] ; then
        echo_error_out "Failed to read the (optional) '${c_n}id$c_e' tasks Object (for trigger '$c_n$machine$c_e') from the workflow '$c_n$workflow$c_e'."

        return 1
      fi

      if [[ $id == "" ]] ; then
        id=$(uuidgen -r)
      fi

      prepare_workflow_item "$id" "$type" "$machine" "$name" "$workflow_file"
      if [[ $? -ne 0 ]] ; then return 1 ; fi

      write_json_file "${directory_generated}triggers/$machine.json"
      if [[ $? -ne 0 ]] ; then return 1 ; fi
    fi

    let i++
  done

  if [[ $failure -ne 0 ]] ; then
    echo_error_out "Failed to load the triggers from the workflow: '$c_n$workflow$c_e'."

    return 1
  fi

  return 0
}
