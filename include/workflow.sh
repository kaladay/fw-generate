#!/bin/bash
#
# An fw-generate script intended to be included by the main script file (usually fw-generate.sh).
#

unload_workflow_sh() {

  unset load_workflow
  unset load_workflow_settings
  unset load_workflow_tasks
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

  load_workflow_settings
  if [[ $? -ne 0 ]] ; then return 1 ; fi

  tasks_total=$(fss_basic_list_read +Qn -cn tasks ${workflow_file} | fss_extended_read +Qn -t)

  if [[ $tasks_total != "" ]] ; then
    let tasks_total=$tasks_total
  fi

  if [[ ${tasks_total} -eq 0 ]] ; then
    echo_error_out "The workflow '${c_n}${workflow}${c_e}' does not have any tasks."

    return 1
  fi

  # Create start task.
  existing=$(fss_basic_list_read +Qn -cn tasks ${workflow_file} | fss_extended_read +Qn -ton startEvent)

  if [[ $? -ne 0 ]] ; then
    echo_error_out "Failed to read the workflow '${c_n}${workflow}${c_e}'."

    return 1
  fi

  if [[ $existing -eq 0 ]] ; then
    let j=1

    tasks_task[0]="startEvent"
    tasks_machine[0]="start"
    tasks_human[0]="Start"
    task=${tasks_machine[0]}

    id=$(fss_basic_list_read +Qn -cn ${tasks_machine[0]} ${workflow_file} | fss_basic_read +Qn -cns id 0)

    if [[ $? -ne 0 ]] ; then
      echo_error_out "Failed to read the (optional) '{c_n}id${c_e}' tasks Object (for $task) from the workflow '${c_n}${workflow}${c_e}'."

      return 1
    fi

    if [[ ${id} == "" ]] ; then
      id=$(uuidgen -r)
    fi

    tasks_uuid[0]=${id}
  fi

  # Create tasks.
  while [[ ${i} -lt ${tasks_total} ]] ; do

    tasks_task[$j]=$(fss_basic_list_read +Qn -cn tasks ${workflow_file} | fss_extended_read +Qn -oa ${i})
    if [[ $? -ne 0 ]] ; then let failure=1 ; break ; fi

    tasks_machine[$j]=$(fss_basic_list_read +Qn -cn tasks ${workflow_file} | fss_extended_read +Qn -cas ${i} 0)
    if [[ $? -ne 0 ]] ; then let failure=1 ; break ; fi

    tasks_human[$j]=$(fss_basic_list_read +Qn -cn tasks ${workflow_file} | fss_extended_read +Qn -cas ${i} 1)
    if [[ $? -ne 0 ]] ; then let failure=1 ; break ; fi

    id=$(fss_basic_list_read +Qn -cn tasks ${workflow_file} | fss_extended_read +Qn -cas ${i} 2)
    if [[ $? -ne 0 ]] ; then let failure=1 ; break ; fi

    task=${tasks_machine[$j]}

    if [[ ${id} == "" ]] ; then
      id=$(fss_basic_list_read +Qn -cn ${tasks_machine[$j]} ${workflow_file} | fss_basic_read +Qn -cns id 0)

      if [[ $? -ne 0 ]] ; then
        echo_error_out "Failed to read the (optional) '{c_n}id${c_e}' tasks Object (for $task) from the workflow '${c_n}${workflow}${c_e}'."

        return 1
      fi
    fi

    if [[ ${id} == "" ]] ; then
      id=$(uuidgen -r)
    fi

    tasks_uuid[$j]="${id}"

    check_exists_already "${directory_generated}${task}.json" "generated workflow"
    if [[ $? -ne 0 ]] ; then return 1 ; fi

    let i++
    let j++
  done

  if [[ ${failure} -ne 0 ]] ; then
    echo_error_out "Failed to read the tasks Object from the workflow '${c_n}${workflow}${c_e}'."

    return 1
  fi

  # If the startEvent has been automatically added, then increment before reusing the "existing" variable.
  if [[ $existing -eq 0 ]] ; then
    let tasks_total++
  fi

  # Create stop task.
  existing=$(fss_basic_list_read +Qn -cn tasks ${workflow_file} | fss_extended_read +Qn -ton endEvent)

  if [[ $? -ne 0 ]] ; then
    echo_error_out "Failed to read the workflow '${c_n}${workflow}${c_e}'."

    return 1
  fi

  if [[ $existing -eq 0 ]] ; then
    tasks_task[$j]="endEvent"
    tasks_machine[$j]="end"
    tasks_human[$j]="End"
    task=${tasks_machine[$j]}

    id=$(fss_basic_list_read +Qn -cn ${tasks_machine[$j]} ${workflow_file} | fss_basic_read +Qn -cns id 0)

    if [[ $? -ne 0 ]] ; then
      echo_error_out "Failed to read the (optional) '{c_n}id${c_e}' tasks Object (for $task) from the workflow '${c_n}${workflow}${c_e}'."

      return 1
    fi

    if [[ ${id} == "" ]] ; then
      id=$(uuidgen -r)
    fi

    tasks_uuid[$j]=${id}

    # Increment to account for endEvent.
    let tasks_total++
  fi

  return 0
}

load_workflow_settings() {
  local object=
  local object_name=
  local object_name_previous=
  local object_key=
  local content=
  local type=
  local template_file="${directory_input}templates/workflow.fss"

  local -i i=0
  local -i j=0
  local -i objects_workflow=0
  local -i objects_template=0
  local -a data_workflow=()
  local -a data_template=()

  let objects_template=$(fss_basic_list_read +Qn -ocOt ${template_file})
  let objects_workflow=$(fss_basic_list_read +Qn -ocOt ${workflow_file})

  if [[ ${object}s_workflow == 0 && ${object}s_template == 0 ]] ; then
    echo_error_out "Both the workflow '${c_n}${workflow}${c_e}' and the template '${c_n}${template_file}${c_e}' the are either empty or have no valid ${c_n}Objects${c_e}."

    return 1
  fi

  while [[ ${i} -lt ${object}s_template ]] ; do

    object=$(fss_basic_list_read +Qn -oa 0 ${workflow_file})

    if [[ $(echo -n "${object}" | grep -sPo "[^.]+\.[^\s]*") == "" ]] ; then
      object_name="${object}"
      object_key=
    else
      object_name=$(echo -n "${object}" | grep -sPo "[^.]+\." | grep -sPo "[^.]+")
      object_key=$(echo -n "${object}" | grep -sPo "\.[^\s]+" | grep -sPo "\.[^\s]+$" | grep -sPo "[^.].*")
    fi

    if [[ ${object}_name_previous == "" ]] ; then
      object_name_previous="${object}_name"
    elif [[ "${object}_name_previous" != "${object}_name" ]] ; then
      # @todo add all ${object}_name found in the workflow file here (also needs to be aware of override).
      echo "TODO"
    fi

    # if workflow defines an object name, then it replaces/overrides all existing values from the template for that name.
    if [[ $(fss_basic_list_read +Qn -on "${object}" ${workflow_file}) != "" ]] ; then
      let j=0

      # @todo walk through entire workflow for any additional lines to add.
      while [[ $j -lt ${object}s_workflow ]] ; do
        echo "TODO"
        let j++
      done
    fi

    let i++
  done

  # @todo below is not updated.

  for object in ${object}s_workflow ; do

    if [[ ${object} == "settings" || $(echo -n ${object} | grep -sPo "settings\.[\w+-]+") != "" ]] ; then
      objects_settings="${objects_settings}${object} "
    fi
  done

  return 0
}

load_workflow_tasks() {

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

  # @todo the main workflow settings are now being loaded differently and this code block needs to be updated.

  # ID, if supplied is used, otherwise is generated.
  id=$(fss_basic_list_read +Qn -cn settings ${workflow_file} | fss_basic_read +Qn -cns id 0)

  if [[ $? -ne 0 ]] ; then
    echo_error_out "Failed to read the (optional) '{c_n}id${c_e}' settings Object from the workflow '${c_n}${workflow}${c_e}'."

    return 1
  fi

  if [[ ${id} == "" ]] ; then
    id=$(uuidgen -r)
  fi

  # The name, if supplied is used, otherwise is created from the name given on the program input.
  name=$(fss_basic_list_read +Qn -cn settings ${workflow_file} | fss_basic_read +Qn -cns name 0)

  if [[ $? -ne 0 ]] ; then
    echo_error_out "Failed to read the (optional) '{c_n}name${c_e}' settings Object from the workflow '${c_n}${workflow}${c_e}'."

    return 1
  fi

  if [[ ${name} == "" ]] ; then
    name=${workflow}
  fi

  echo_out "Generating Workflow: ${id}, \"${name}\""

  prepare_json_line 0 "value" "id" "${id}"
  prepare_json_line 0 "value" "name" "${name}"

  load_template_task "workflow" "settings"
  if [[ $? -ne 0 ]] ; then return 1 ; fi

  # Nodes are generated and are not loaded from the workflow template.
  prepare_json_line 0 "array" "nodes"

  let i=0
  while [[ ${i} -lt ${tasks_total} ]] ; do

    id=${tasks_uuid[${i}]}
    type=${tasks_task[${i}]}

    prepare_json_line 1 "value" "" "{{mod-workflow}}/${type}/${id}"
    if [[ $? -ne 0 ]] ; then return 1 ; fi

    let i++
  done

  prepare_json_line_array_or_map_end 0 "array"

  write_json_file "${directory_generated}workflow.json"
  if [[ $? -ne 0 ]] ; then return 1 ; fi

  create_workflow_nodes
  if [[ $? -ne 0 ]] ; then return 1 ; fi

  if [[ ! -f "${directory_generated}setup.json" ]] ; then
    echo "{}" > "${directory_generated}setup.json"

    if [[ $? -ne 0 ]] ; then
      echo_error_out "Failed to create the setup JSON file: '${c_n}${directory_generated}setup.json${c_e}'."

      return 1
    fi
  fi

  data=$(fss_basic_list_read +Qn -ont triggers ${workflow_file})

  if [[ $? -ne 0 ]] ; then
    echo_error_out "Failed to read the workflow file: '${c_n}${workflow_file}${c_e}'."

    return 1
  fi

  if [[ $data -gt 0 && ! -d "${directory_generated}triggers" ]] ; then
    mkdir "${directory_generated}triggers"

    if [[ $? -ne 0 ]] ; then
      echo_error_out "Failed to create the triggers directory: '${c_n}${directory_generated}triggers${c_e}'."

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

  while [[ ${i} -lt ${tasks_total} ]] ; do

    local -a properties=()
    local -a values=()
    local -a depths=()
    let total=0

    id=${tasks_uuid[${i}]}
    type=${tasks_task[${i}]}
    machine=${tasks_machine[${i}]}
    name=${tasks_human[${i}]}

    check_exists_already "${directory_generated}nodes/${machine}.json" "generated node"
    if [[ $? -ne 0 ]] ; then return 1 ; fi

    prepare_workflow_item "${id}" "${type}" "${machine}" "${name}" "${workflow_file}"
    if [[ $? -ne 0 ]] ; then return 1 ; fi

    write_json_file "${directory_generated}nodes/${machine}.json"
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
  local id="${1}"
  local type="${2}"
  local machine="${3}"
  local name="${4}"

  echo_out "Generating Item: ${id}, ${type}, ${machine}, \"${name}\""

  prepare_json_line 0 "value" "id" "${id}"
  prepare_json_line 0 "value" "name" "${name}"

  load_template_task "${type}" "${machine}"
  if [[ $? -ne 0 ]] ; then return 1 ; fi

  return 0
}

# Arguments:
#   1) All of the triggers as loaded from fss_basic_list.
prepare_workflow_triggers() {
  local triggers="${1}"
  local id=
  local type=
  local machine=
  local name=
  local -i lines=
  local -i failure=0
  local -i i=0

  lines=$(fss_basic_list_read +Qn -cn triggers ${workflow_file} | fss_extended_read +Qn -ot)
  let failure=$?

  while [[ ${i} -lt ${lines} && ${failure} -eq 0 ]] ; do

    local -a properties=()
    local -a values=()
    local -a depths=()
    local -i total=0

    type=$(fss_basic_list_read +Qn -cn triggers ${workflow_file} | fss_extended_read +Qn -oea ${i})
    let failure=$?

    if [[ ${failure} -eq 0 ]] ; then
      machine=$(fss_basic_list_read +Qn -cn triggers ${workflow_file} | fss_extended_read +Qn -cqaes ${i} 0)
      let failure=$?
    fi

    if [[ ${failure} -eq 0 ]] ; then
      name=$(fss_basic_list_read +Qn -cn triggers ${workflow_file} | fss_extended_read +Qn -cqaes ${i} 1)
      let failure=$?
    fi

    if [[ ${failure} -eq 0 ]] ; then
      check_exists_already "${directory_generated}triggers/${machine}.json" "generated trigger"
      if [[ $? -ne 0 ]] ; then return 1 ; fi

      # ID, if supplied is used, otherwise is generated.
      id=$(fss_basic_list_read +Qn -cn ${machine} ${workflow_file} | fss_basic_read +Qn -cns id 0)

      if [[ $? -ne 0 ]] ; then
        echo_error_out "Failed to read the (optional) '${c_n}id${c_e}' tasks Object (for trigger '${c_n}${machine}${c_e}') from the workflow '${c_n}${workflow}${c_e}'."

        return 1
      fi

      if [[ ${id} == "" ]] ; then
        id=$(uuidgen -r)
      fi

      prepare_workflow_item "${id}" "${type}" "${machine}" "${name}" "${workflow_file}"
      if [[ $? -ne 0 ]] ; then return 1 ; fi

      write_json_file "${directory_generated}triggers/${machine}.json"
      if [[ $? -ne 0 ]] ; then return 1 ; fi
    fi

    let i++
  done

  if [[ ${failure} -ne 0 ]] ; then
    echo_error_out "Failed to load the triggers from the workflow: '${c_n}${workflow}${c_e}'."

    return 1
  fi

  return 0
}
