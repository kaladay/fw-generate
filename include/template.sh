#!/bin/bash
# fw-generate script to be included.

unload_template_sh() {

  unset load_template_task
  unset load_template_task_workflow
  unset find_last_array_or_map
  unset unload_template_sh
}

# Arguments:
#   1) The type (which is essentially the filename without the ".fss"), such as "connectTo".
#   2) The machine name.
load_template_task() {
  local type="$1"
  local machine="$2"
  local template_file="${directory_input}templates/${type}.fss"
  local template_objects=
  local template_object=
  local workflow_objects_task=
  local workflow_objects=
  local workflow_object=
  local object_group=
  local object=
  local content=
  local processed="id name "
  local -i template_lines=0
  local -i workflow_lines=0
  local -i i=0
  local -i j=0
  local -i failure_template=0
  local -i failure_workflow=0
  local -i lines=0

  if [[ -f $template_file ]] ; then
    if [[ ! -r $template_file ]] ; then
      echo_error_out "The template file '$c_n$template_file$c_e' exists but cannot be read."

      return 1
    fi

    let template_lines=$(fss_basic_read -oqte $template_file)
    if [[ $? -ne 0 ]] ; then
      echo_error_out "Failed while trying to read the template file '$c_n$template_file$c_e'."

      return 1
    fi

    while [[ $i -lt $template_lines ]] ; do

      template_object=$(fss_basic_read -oqae $i $template_file)
      failure_template=$?
      if [[ $failure_template -ne 0 ]] ; then break ; fi

      content=$(fss_basic_read -cqae $i $template_file)
      failure_template=$?
      if [[ $failure_template -ne 0 ]] ; then break ; fi

      # Process normal Object.
      if [[ $(echo -n "$template_object" | grep -sPo "\.") == "" && $content != "{}" && $content != "[]" ]] ; then
        workflow_object=$(fss_basic_list_read -cqna $machine 0 $workflow_file | fss_basic_read -oqena $template_object 0)
        failure_workflow=$?
        if [[ $failure_workflow -ne 0 ]] ; then break ; fi

        if [[ $workflow_object != "" ]] ; then
          content=$(fss_basic_list_read -cqna $machine 0 $workflow_file | fss_basic_read -cqena $template_object 0)
          failure_workflow=$?
          if [[ $failure_workflow -ne 0 ]] ; then break ; fi
        fi

        prepare_json_line 0 "$template_object" "$content"
        processed="$processed$template_object "

      # Process array and map Object.
      else
        content=$(fss_basic_read -cqae $i $template_file)
        failure_template=$?
        if [[ $failure_template -ne 0 ]] ; then break ; fi

        # Process array Object.
        if [[ $content == "[]" || $(echo -n "$template_object" | grep -sPo "\.$") != "" ]] ; then
          if [[ $(echo -n "$template_object" | grep -sPo "\.$") == "" ]] ; then
            object_group="$template_object"
          else
            object_group=$(echo -n "$template_object" | grep -sPo "[^.]+\.$" | grep -sPo "[^.]+")
          fi

          workflow_objects=$(fss_basic_list_read -oqn ${machine}.$object_group. $workflow_file)
          failure_workflow=$?
          if [[ $failure_workflow -ne 0 ]] ; then break ; fi

          if [[ $workflow_objects == "" ]] ; then
            let j=$i
            find_last_array_or_map $template_lines "$object_group" "$template_file"
            failure_template=$?
            if [[ $failure_template -ne 0 ]] ; then break ; fi

            if [[ $j -eq $i ]] ; then
              prepare_json_line -1 "$object_group" "empty-array"
            else
              prepare_json_line -1 "$object_group" "array"

              if [[ $content != "[]" ]] ; then
                prepare_json_line -2 "" "$content"
              fi

              let i++

              while [[ $i -le $j ]] ; do
                content=$(fss_basic_read -cqae $i $template_file)
                failure_template=$?
                if [[ $failure_template -ne 0 ]] ; then break ; fi

                prepare_json_line -2 "" "$content"

                let i++
              done

              if [[ $failure_template -ne 0 ]] ; then break ; fi

              prepare_json_line_array_or_map_end -1 "array"

              let i--
            fi
          else
            workflow_lines=$(fss_basic_list_read -cqnet ${machine}.$object_group $workflow_file)

            if [[ $workflow_lines -eq 0 ]] ; then
              prepare_json_line -1 "$object_group" "empty-array"
            else
              prepare_json_line -1 "$object_group" "array"

              let j=0
              while [[ $j -lt $workflow_lines ]] ; do

                # FIXME: bug in fss_basic_list_read where -a cannot be used with -n and -l (once fixed, add "-a 0" for all appropriate fss_basic_list_read uses).
                content=$(fss_basic_list_read -cqnle ${machine}.$object_group $j $workflow_file)
                failure_template=$?
                if [[ $failure_template -ne 0 ]] ; then break ; fi

                if [[ $content != "" ]] ; then
                  prepare_json_line -2 "" "$content"
                fi

                let j++
              done

              if [[ $failure_template -ne 0 ]] ; then break ; fi

              prepare_json_line_array_or_map_end -1 "array"
            fi

            # skip past all array Objects in template, now that the workflow settings are being used.
            let j=$i
            find_last_array_or_map $template_lines "$object_group" "$template_file"
            failure_template=$?
            if [[ $failure_template -ne 0 ]] ; then break ; fi

            if [[ $j -gt $i ]] ; then
              let i=$j
            fi
          fi

          processed="$processed$template_object "

        # Process map Object.
        elif [[ $content == "{}" || $(echo -n "$template_object" | grep -sPo "^[^.]+\.[^.]+$") != "" ]] ; then
          if [[ $(echo -n "$template_object" | grep -sPo "^[^.]+\.") == "" ]] ; then
            object_group="$template_object"
            object=
          else
            object_group=$(echo -n "$template_object" | grep -sPo "^[^.]+\." | grep -sPo "[^.]+")
            object=$(echo -n "$template_object" | grep -sPo "\.[^.]+$" | grep -sPo "[^.]+")
          fi

          workflow_objects=$(fss_basic_list_read -oqn ${machine}.$object_group $workflow_file)
          failure_workflow=$?
          if [[ $failure_workflow -ne 0 ]] ; then break ; fi

          if [[ $workflow_objects == "" ]] ; then
            let j=$i
            find_last_array_or_map $template_lines "$object_group" "$template_file"
            failure_template=$?
            if [[ $failure_template -ne 0 ]] ; then break ; fi

            if [[ $j -eq $i ]] ; then
              prepare_json_line -1 "$object_group" "empty-map"
            else
              prepare_json_line -1 "$object_group" "map"

              if [[ $content != "{}" ]] ; then
                prepare_json_line -2 "$object" "$content"

                processed="$processed$object_group.$object "
              fi

              let i++

              while [[ $i -le $j ]] ; do
                object=$(fss_basic_read -oqae $i $template_file)
                failure_template=$?
                if [[ $failure_template -ne 0 ]] ; then break ; fi
                if [[ $object == "" ]] ; then break ; fi

                content=$(fss_basic_read -cqae $i $template_file)
                failure_template=$?
                if [[ $failure_template -ne 0 ]] ; then break ; fi

                object=$(echo -n "$object" | grep -sPo "\.[^.]+$" | grep -sPo "[^.]+")

                prepare_json_line -2 "$object" "$content"
                processed="$processed$object_group.$object "

                let i++
              done

              if [[ $failure_template -ne 0 ]] ; then break ; fi

              prepare_json_line_array_or_map_end -1 "map"

              let i--
            fi
          else
            workflow_lines=$(fss_basic_list_read -cqnet ${machine}.$object_group $workflow_file)

            if [[ $workflow_lines -eq 0 ]] ; then
              prepare_json_line -1 "$object_group" "empty-map"
            else
              prepare_json_line -1 "$object_group" "map"

              let j=0
              while [[ $j -lt $workflow_lines ]] ; do

                object=$(fss_basic_list_read -cqnle ${machine}.$object_group $j $workflow_file | fss_basic_read -oq)
                failure_template=$?
                if [[ $failure_template -ne 0 ]] ; then break ; fi
                if [[ $object == "" ]] ; then break ; fi

                content=$(fss_basic_list_read -cqnle ${machine}.$object_group $j $workflow_file | fss_basic_read -cq)
                failure_template=$?
                if [[ $failure_template -ne 0 ]] ; then break ; fi

                prepare_json_line -2 "$object" "$content"
                processed="$processed$object_group.$object "

                let j++
              done

              if [[ $failure_template -ne 0 ]] ; then break ; fi

              prepare_json_line_array_or_map_end -1 "map"
            fi

            # skip past all array Objects in template, now that the workflow settings are being used.
            let j=$i
            find_last_array_or_map $template_lines "$object_group" "$template_file"
            failure_template=$?
            if [[ $failure_template -ne 0 ]] ; then break ; fi

            if [[ $j -gt $i ]] ; then
              let i=$j
            fi
          fi

          processed="$processed$template_object "

        else
          # unknown/unsupported data structure.
          let i++

          continue
        fi
      fi

      let i++
    done

    if [[ $failure_template -ne 0 ]] ; then
      echo_error_out "Failed while trying to read the template file '$c_n$template_file$c_e'."

      return 1
    elif [[ $failure_workflow -ne 0 ]] ; then
      echo_error_out "Failed while trying to read the template file '$c_n$workflow_file$c_e'."

      return 1
    fi
  fi

  load_template_task_workflow

  if [[ $failure_workflow -ne 0 ]] ; then
    echo_error_out "Failed while trying to read the template file '$c_n$workflow_file$c_e'."

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

    object=$(fss_basic_read -oqae $j $file)
    if [[ $? -ne 0 ]] ; then return 1 ; fi

    if [[ $(echo -n "$object" | grep -sPo "^$match\.") == "" && $object != "$match" ]] ; then
      let j--

      break;
    fi

    let j++
  done

  return 0
}

# This is an extension of load_template_task() moved to a separate function for organization purposes.
# This requires variables from load_template_task_workflow().
load_template_task_workflow() {
  local group=

  workflow_objects=$(fss_basic_list_read -oq $workflow_file)
  failure_workflow=$?
  if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi

  # Build list of workflow objects that are associated with the current task.
  for workflow_object in $workflow_objects ; do

    if [[ $workflow_object == "$machine" || $(echo -n $workflow_object | grep -sPo "\b$machine\.[\w+-]+($|\.$)") != "" ]] ; then
      workflow_objects_task="$workflow_objects_task$workflow_object "
    fi
  done

  for workflow_object in $workflow_objects_task ; do

    workflow_lines=$(fss_basic_list_read -cqnet $workflow_object $workflow_file)
    failure_workflow=$?
    if [[ $failure_workflow -ne 0 ]] ; then return 1 ; fi

    if [[ $(echo -n "$workflow_object" | grep -sPo "\.") == "" ]] ; then
      let i=0
      while [[ $i -lt $workflow_lines ]] ; do

        object=$(fss_basic_list_read -cqnle $workflow_object $i $workflow_file | fss_basic_read -oq)
        failure_workflow=$?
        if [[ $failure_workflow -ne 0 ]] ; then break ; fi

        if [[ $(echo -n "$processed" | grep -sPo "(^|\s)\b$object\b(\s|$)") != "" ]] ; then
          let i++

          continue;
        fi

        if [[ $object == "" ]] ; then
          let i++

          continue
        fi

        content=$(fss_basic_list_read -cqnle $workflow_object $i $workflow_file | fss_basic_read -cq)
        failure_workflow=$?
        if [[ $failure_workflow -ne 0 ]] ; then break ; fi

        prepare_json_line 0 "$object" "$content"
        processed="$processed$object "

        let i++
      done

      processed="$processed$workflow_object "
    else
      group=$(echo -n "$workflow_object" | grep -sPo "\.[^.]+($|\.$)" | grep -sPo "[^.]+")
      if [[ $group == "" ]] ; then continue ; fi

      if [[ $(echo -n "$processed" | grep -sPo "(^|\s)\b$workflow_object\b(\s|$)") != "" ]] ; then
        continue;
      fi

      # Process a map Object.
      if [[ $(echo -n "$workflow_object" | grep -sPo "\.$") == "" ]] ; then
        prepare_json_line -1 "$group" "map"

        let i=0
        while [[ $i -lt $workflow_lines ]] ; do

          object=$(fss_basic_list_read -cqnle $workflow_object $i $workflow_file | fss_basic_read -oq)
          failure_workflow=$?
          if [[ $failure_workflow -ne 0 ]] ; then break ; fi

          if [[ $object == "" ]] ; then
            let i++

            continue
          fi

          content=$(fss_basic_list_read -cqnle $workflow_object $i $workflow_file | fss_basic_read -cq)
          failure_workflow=$?
          if [[ $failure_workflow -ne 0 ]] ; then break ; fi

          prepare_json_line -2 "$object" "$content"

          let i++
        done

        if [[ $failure_workflow -ne 0 ]] ; then break ; fi

        prepare_json_line_array_or_map_end -1 "map"

      # Process an array Object.
      else
        prepare_json_line -1 "$group" "array"

        let i=0
        while [[ $i -lt $workflow_lines ]] ; do

          content=$(fss_basic_list_read -cqnle $workflow_object $i $workflow_file | fss_basic_read -ocq)
          failure_workflow=$?
          if [[ $failure_workflow -ne 0 ]] ; then break ; fi

          if [[ $content != "" ]] ; then
            prepare_json_line -2 "" "$content"
          fi

          let i++
        done

        if [[ $failure_workflow -ne 0 ]] ; then break ; fi

        prepare_json_line_array_or_map_end -1 "array"
      fi

      processed="$processed$workflow_object "
    fi

    if [[ $failure_workflow -ne 0 ]] ; then break ; fi

    if [[ $workflow_lines -eq 0 && $(echo -n "$workflow_object" | grep -sPo "\.") != "" ]] ; then
      if [[ $(echo -n "$workflow_object" | grep -sPo "\.$") == "" ]] ; then
        prepare_json_line -1 "$group" "empty-map"
      else
        prepare_json_line -1 "$group" "empty-array"
      fi
    fi
  done
}
