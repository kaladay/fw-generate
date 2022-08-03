#!/bin/bash
# fw-generate script to be included.

unload_template_sh() {

  unset load_template_task
  unset load_template_task_process_complex
  unset load_template_task_process_complex_prepare
  unset load_template_task_process_simple
  unset load_template_task_workflow
  unset find_last_array_or_map
  unset unload_template_sh
}

# Arguments:
#   1) The type (which is essentially the filename without the ".fss"), such as "connectTo".
#   2) The machine name.
#
# This loads the templates and the workflow data that are described under "tasks" in the workflow.
load_template_task() {
  local type="$1"
  local machine="$2"
  local template_file="${directory_input}templates/${type}.fss"
  local template_object=
  local object=
  local content=
  local processed="id name "
  local -i template_lines=0
  local -i i=0
  local -i j=0
  local -i failure_template=0
  local -i failure_workflow=0
  local -i lines=0
  local -i template_objects_total=0

  if [[ -f $template_file ]] ; then
    if [[ ! -r $template_file ]] ; then
      echo_error_out "The template file '$c_n$template_file$c_e' exists but cannot be read."

      return 1
    fi

    let template_lines=$(fss_basic_read +Q -ote $template_file)
    if [[ $? -ne 0 ]] ; then
      echo_error_out "Failed while trying to read the template file '$c_n$template_file$c_e'."

      return 1
    fi

    while [[ $failure_template -eq 0 && $i -lt $template_lines ]] ; do

      template_object=$(fss_basic_read +Q -oae $i $template_file)
      failure_template=$?
      if [[ $failure_template -ne 0 ]] ; then break ; fi

      content=$(fss_basic_read +Q -cae $i $template_file)
      failure_template=$?
      if [[ $failure_template -ne 0 ]] ; then break ; fi

      if [[ $(echo -n "$template_object" | grep -sPo "\.") == "" && $content != "{}" && $content != "[]" ]] ; then
        load_template_task_process_simple
      elif [[ $content == "{}" || $content == "[]" ]] ; then
         load_template_task_process_complex
      fi

      let i++
    done

    if [[ $failure_template -ne 0 ]] ; then
      echo_error_out "Failed while trying to read the template file '$c_n$template_file$c_e'."

      return 1
    fi
  fi

  if [[ $failure_workflow -eq 0 ]] ; then
    load_template_task_workflow
  fi

  if [[ $failure_workflow -ne 0 ]] ; then
    echo_error_out "Failed while trying to read the workflow file '$c_n$workflow_file$c_e'."

    return 1
  fi

  return 0
}

# Arguments:
#   1) The total number of lines to process.
#   2) The match to find.
#   3) The file to search.
#
# This requires "j" to be defined in a parent scope and will update "j".
find_last_array_or_map() {
  local -i lines=$1
  local match="$2"
  local file="$3"
  local object=

  while [[ $j -lt $lines ]] ; do

    object=$(fss_basic_read +Q -oae $j $file)
    if [[ $? -ne 0 ]] ; then return 1 ; fi

    if [[ $(echo -n "$object" | grep -sPo "^$match\.") == "" && $object != "$match" ]] ; then
      let j--

      break;
    fi

    let j++
  done

  return 0
}

# This is an extension of load_template_task() moved into a separate function for organization purposes.
# This requires variables from load_template_task().
load_template_task_process_complex() {
  local object_group=
  local -i total_in_all=0
  local -i total_in_template=0
  local -i total_in_workflow=0

  if [[ $(echo -n "$template_object" | grep -sPo "\.$") == "" ]] ; then
    object_group="$template_object"
  else
    object_group=$(echo -n "$template_object" | grep -sPo "[^.]+\.$" | grep -sPo "[^.]+")
  fi

  if [[ $content == "[]" ]] ; then
    total_in_template=$(fss_basic_read +Q -ton "${machine}.$object_group\.$" "$template_file")
    failure_workflow=$?
    if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi

    total_in_workflow=$(fss_basic_list_read +Q -ton "${machine}.$object_group\.$" "$workflow_file")
    failure_workflow=$?
    if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi

    let total_in_all=$total_in_template+$total_in_workflow

    if [[ $total_in_all -eq 0 ]] ; then
      prepare_json_line 0 "empty-array" "$object_group"
    else
      load_template_task_process_complex_prepare "array"
    fi
  elif [[ $content == "{}" ]] ; then
    total_in_template=$(fss_basic_read +Q -ton "${machine}.$object_group$" "$template_file")
    failure_workflow=$?
    if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi

    total_in_workflow=$(fss_basic_list_read +Q -ton "${machine}.$object_group$" "$workflow_file")
    failure_workflow=$?
    if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi

    let total_in_all=$total_in_template+$total_in_workflow

    if [[ $total_in_all -eq 0 ]] ; then
      prepare_json_line 0 "empty-object" "$object_group"
    else
      load_template_task_process_complex_prepare "object"
    fi
  fi

  return 0
}

# Arguments:
#   1) The type, either: 'array' or 'map'.
#
# This is an extension of load_template_task_process_complex() moved to a separate function for organization purposes.
# This requires variables from load_template_task_process_complex().
load_template_task_process_complex_prepare() {
  local type="$1"
  local object=
  local content=
  local -i at=0
  local -i at_in_workflow=0
  local -i at_inside=0
  local -i total_inside=0

  if [[ $total_in_workflow -eq 0 ]] ; then
    if [[ $total_in_template -eq 0 ]] ; then
      if [[ $type == "array" ]] ; then
        prepare_json_line 0 "empty-array" "$object_group"
      else
        prepare_json_line 0 "empty-object" "$object_group"
      fi
    else
      prepare_json_line 0 "$type" "$object_group"

      while [[ $at -lt $total_in_template ]] ; do

        if [[ $type == "array" ]] ; then
          object=$(fss_basic_read +Q -ona "${machine}.$object_group\.$" $at "$template_file")
          content=$(fss_basic_read +Q -cna "${machine}.$object_group\.$" $at "$template_file")
        else
          object=$(fss_basic_read +Q -ona "${machine}.$object_group$" $at "$template_file")
          content=$(fss_basic_read +Q -cna "${machine}.$object_group$" $at "$template_file")
        fi

        if [[ $content != "[]" && $content != "{}" ]] ; then
          if [[ $type == "array" ]] ; then
            prepare_json_line 1 "value" "" "$content"
          else
            prepare_json_line 1 "value" "$object" "$content"
          fi

          processed="$processed$object_group.$object "
        fi

        let at++
      done

      prepare_json_line_array_or_map_end 0 $type
    fi
  else
    while [[ $at_in_workflow -lt $total_in_workflow ]] ; do

      prepare_json_line 0 "$type" "$object_group"

      let at=0
      while [[ $at -lt $total_in_template ]] ; do

        if [[ $type == "array" ]] ; then
          object=$(fss_basic_read +Q -ona "${machine}.$object_group\.$" $at "$template_file")
          content=$(fss_basic_read +Q -cna "${machine}.$object_group\.$" $at "$template_file")
        else
          object=$(fss_basic_read +Q -ona "${machine}.$object_group$" $at "$template_file")
          content=$(fss_basic_read +Q -cna "${machine}.$object_group$" $at "$template_file")
        fi

        if [[ $content != "[]" && $content != "{}" ]] ; then
          if [[ $type == "array" ]] ; then
            prepare_json_line 1 "value" "" "$content"
          else
            prepare_json_line 1 "value" "$object" "$content"
          fi

          processed="$processed$object_group.$object "
        fi

        let at++
      done

      if [[ $type == "array" ]] ; then
        total_inside=$(fss_basic_list_read +Q -cna "${machine}.$object_group\.$" $at_in_workflow "$workflow_file" | fss_basic_read +Q -t)
      else
        total_inside=$(fss_basic_list_read +Q -cna "${machine}.$object_group$" $at_in_workflow "$workflow_file" | fss_basic_read +Q -t)
      fi

      let at=0
      while [[ $at -lt $total_inside ]] ; do

        # Object should be a quoted empty string, but it is ignored either way.
        object=$(fss_basic_list_read +Q -cna "${machine}.$object_group\.$" $at_in_workflow "$workflow_file" | fss_basic_read +Q -oa $at "$workflow_file")
        content=$(fss_basic_list_read +Q -cna "${machine}.$object_group\.$" $at_in_workflow "$workflow_file" | fss_basic_read +Q -ca $at "$workflow_file")

        if [[ $content != "[]" && $content != "{}" ]] ; then
          if [[ $type == "array" ]] ; then
            prepare_json_line 1 "value" "" "$content"
          else
            prepare_json_line 1 "value" "$object" "$content"
          fi

          processed="$processed$object_group.$object "
        fi

        let at++
      done
      prepare_json_line_array_or_map_end 0 $type

      let at_in_workflow++
    done
  fi

  return 0
}

# This is an extension of load_template_task() moved to a separate function for organization purposes.
# This requires variables from load_template_task().
load_template_task_process_simple() {
  local inner_content=
  local workflow_object=

  object_group=
  object_type=

  workflow_object=$(fss_basic_list_read +Q -cna $machine 0 $workflow_file | fss_basic_read +Q -oena $template_object 0)
  failure_workflow=$?
  if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi

  if [[ $workflow_object != "" ]] ; then
    inner_content=$(fss_basic_list_read +Q -cna $machine 0 $workflow_file | fss_basic_read +Q -cena $template_object 0)
    failure_workflow=$?
    if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi
  fi

  prepare_json_line 0 "value" "$template_object" "$inner_content"
  processed="$processed$template_object "

  return 0
}

# This is an extension of load_template_task() moved to a separate function for organization purposes.
# This requires variables from load_template_task().
load_template_task_workflow() {
  local object=
  local content=
  local group=
  local group_wrapper=
  local workflow_object=
  local workflow_objects=
  local workflow_objects_task=
  local processed_objects=
  local -i workflow_object_total=0
  local -i workflow_content_total=0
  local -i at=0
  local -i i=0
  local -i depth=0
  local -i depth_inner=0

  workflow_objects=$(fss_basic_list_read +Q -o $workflow_file)
  failure_workflow=$?
  if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi

  # Build list of workflow objects that are associated with the current task.
  for workflow_object in $workflow_objects ; do

    if [[ $workflow_object == "$machine" || $(echo -n $workflow_object | grep -sPo "\b$machine\.[\w+-]+($|\.$)") != "" ]] ; then
      workflow_objects_task="$workflow_objects_task$workflow_object "
    fi
  done

  for workflow_object in $workflow_objects_task ; do

    if [[ $(echo -n "$processed_objects" | grep -sPo "(^|\s)\b$workflow_object\b(\s|$)") != "" ]] ; then
      continue;
    fi

    workflow_object_total=$(fss_basic_list_read +Q -onet $workflow_object $workflow_file)
    failure_workflow=$?
    if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi

    if [[ $workflow_object_total -gt 1 ]] ; then

      # JSON does not allow multiple duplicate keys in their maps.
      # Force a size to 1 to only build the first key for generated JSON maps.
      if [[ $(echo -n "$workflow_object" | grep -sPo "\.[^.]+($|\.$)") == "" ]] ; then
        let workflow_object_total=1
        let depth=0
      else
        let depth=1

        group_wrapper=$(echo -n "$workflow_object" | grep -sPo "\.[^.]+\.$" | grep -sPo "[^.]+")

        prepare_json_line 0 "array" "$group_wrapper"
      fi
    else
      let depth=0
    fi

    let at=0
    while [[ $at -lt $workflow_object_total ]] ; do

      workflow_content_total=$(fss_basic_list_read +Q -cnaet $workflow_object $at $workflow_file)
      failure_workflow=$?
      if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi

      if [[ $workflow_content_total -eq 0 && $(echo -n "$workflow_object" | grep -sPo "\.") != "" ]] ; then
        if [[ $(echo -n "$workflow_object" | grep -sPo "\.$") == "" ]] ; then
          prepare_json_line 0 "empty-map" "$group"
        else
          prepare_json_line 0 "empty-array" "$group"
        fi

        let at++

        continue
      fi

      # Process value.
      if [[ $(echo -n "$workflow_object" | grep -sPo "\.") == "" ]] ; then
        let i=0
        while [[ $i -lt $workflow_content_total ]] ; do

          object=$(fss_basic_list_read +Q -cnale $workflow_object $at $i $workflow_file | fss_basic_read +Q -o)
          failure_workflow=$?
          if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi

          if [[ $(echo -n "$processed" | grep -sPo "(^|\s)\b$workflow_object[$at]$object\b(\s|$)") != "" ]] ; then
            let i++

            continue;
          fi

          if [[ $object == "" ]] ; then
            let i++

            continue
          fi

          content=$(fss_basic_list_read +Q -cnale $workflow_object $at $i $workflow_file | fss_basic_read +Q -c)
          failure_workflow=$?
          if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi

          prepare_json_line 0 "value" "$object" "$content"

          processed="$processed$workflow_object[$at]$object "

          let i++
        done

      # Process array/object.
      else
        group=$(echo -n "$workflow_object" | grep -sPo "\.[^.]+($|\.$)" | grep -sPo "[^.]+")

        if [[ $group == "" ]] ; then
          let at++

          continue
        fi

        if [[ $(echo -n "$processed" | grep -sPo "(^|\s)\b$workflow_object\b(\s|$)") != "" ]] ; then
          let at++

          continue
        fi

        # Process a map Object.
        if [[ $(echo -n "$workflow_object" | grep -sPo "\.$") == "" ]] ; then
          prepare_json_line $depth "map" "$group"

          total=$(fss_basic_list_read +Q -cnale $workflow_object $at $i $workflow_file | fss_basic_read +Q -t)
          failure_workflow=$?
          if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi

          let i=0
          let depth_inner=$depth+1
          while [[ $i -lt $workflow_content_total ]] ; do

            object=$(fss_basic_list_read +Q -cnale $workflow_object $at $i $workflow_file | fss_basic_read +Q -o)
            failure_workflow=$?
            if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi

            if [[ $object == "" ]] ; then
              let i++

              continue
            fi

            content=$(fss_basic_list_read +Q -cnalet $workflow_object $at $i $workflow_file)
            failure_workflow=$?
            if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi

            prepare_json_line $depth_inner "value" "$object" "$content"

            let i++
          done

          prepare_json_line_array_or_map_end $depth "map"

        # Process an array object.
        else
          prepare_json_line $depth "object"

          let i=0
          let depth_inner=$depth+1
          while [[ $i -lt $workflow_content_total ]] ; do

            total=$(fss_basic_list_read +Q -cnalet $workflow_object $at $i $workflow_file)
            failure_workflow=$?
            if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi

            if [[ $total -eq 0 ]] ; then
              let i++

              continue
            fi

            content=$(fss_basic_list_read +Q -cnale $workflow_object $at $i $workflow_file | fss_basic_read +Q -c)
            failure_workflow=$?
            if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi

            prepare_json_line $depth_inner "value" "" "$content"

            let i++
          done

          prepare_json_line_array_or_map_end $depth "object"
        fi
      fi

      let at++
    done

    if [[ $depth -eq 1 ]] ; then
      prepare_json_line_array_or_map_end 0 "array"
    fi

    processed="$processed$workflow_object "
    processed_objects="$processed_objects$workflow_object "
  done

  return 0
}
