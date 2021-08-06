#!/bin/bash
# fw-generate script to be included.

unload_main_sh() {
  unset main
  unset main_generate
  unset main_cleanup
  unset unload_main_sh
}

main() {

  # standard main parameters.
  local script_pathname=$0
  local -i get_help=0
  local -i get_version=0
  local no_color=
  local grab_next=
  local parameter=
  local -i parameters_total=$#
  local extra_parameters=
  local -i extra_parameters_total=0
  local -i output_mode=0
  local version="0.1.0"
  local -i failure=0

  # generic
  local -i i=0

  # reset, title, error, warning, highligh, notice, important.
  local c_r="\\033[0m"
  local c_t="\\033[1;33m"
  local c_e="\\033[1;31m"
  local c_w="\\033[0;33m"
  local c_h="\\033[1;49;36m"
  local c_n="\\033[0;01m"
  local c_i="\\033[0;49;36m"

  # program variables.
  local command=
  local directory_input=
  local directory_output=
  local directory_generated=

  local workflow=
  local workflow_file=
  local workflow_objects=
  local workflow_objects_settings=
  local workflow_tasks=

  local -a tasks_task=()
  local -a tasks_machine=()
  local -a tasks_human=()
  local -a tasks_uuid=()
  local -a tasks_template=()
  local -i tasks_total=0

  if [[ $parameters_total -gt 0 ]] ; then
    while [[ $i -lt $parameters_total ]] ; do
      let i++
      parameter="${!i}"

      if [[ $grab_next == "" ]] ; then
        if [[ $parameter == "-h" || $parameter == "--help" ]] ; then
          let get_help=1
        elif [[ $parameter == "-n" || $parameter == "--no_color" ]] ; then
          c_r=""
          c_t=""
          c_e=""
          c_w=""
          c_h=""
          c_n=""
          c_i=""
        elif [[ $parameter == "-s" || $parameter == "--silent" ]] ; then
          if [[ $output_mode -eq 0 ]] ; then
            let output_mode=1
          elif [[ $output_mode -eq 1 ]] ; then
            let output_mode=2
          fi
        elif [[ $parameter == "-i" || $parameter == "--input_directory" ]] ; then
          grab_next="input_directory"
        elif [[ $parameter == "-o" || $parameter == "--output_directory" ]] ; then
          grab_next="output_directory"
        elif [[ $workflow == "" ]] ; then
          workflow="$parameter"
        elif [[ $parameter == "+v" || $parameter == "++version" ]] ; then
          let get_version=1
        else
          extra_parameters[${extra_parameters_total}]=$parameter
          let extra_parameters_total++
        fi
      else
        if [[ $grab_next == "input_directory" ]] ; then
          directory_input=$(echo "$parameter" | sed -e 's|//*|/|g' -e 's|/*$|/|')
          grab_next=
        elif [[ $grab_next == "output_directory" ]] ; then
          directory_output=$(echo "$parameter" | sed -e 's|//*|/|g' -e 's|/*$|/|')
          grab_next=
        else
          break
        fi
      fi
    done
  fi

  if [[ $directory_input == "" ]] ; then
    directory_input="./"
  fi

  if [[ $get_help -eq 0 && $get_version -eq 0 ]] ; then
    if [[ ! -d $directory_input || ! -x $directory_input ]] ; then
      echo_error_out "The input directory '$c_n$directory_input$c_e' is not found, is not executable, or is not a directory."

      return 1
    fi

    if [[ ! -d ${directory_input}templates || ! -x ${directory_input}templates ]] ; then
      echo_error_out "The templates directory '$c_n${directory_input}templates$c_e' is not found, is not executable, or is not a directory."

      return 1
    fi

    if [[ ! -d ${directory_input}workflows || ! -x ${directory_input}workflows ]] ; then
      echo_error_out "The templates directory '$c_n${directory_input}workflows$c_e' is not found, is not executable, or is not a directory."

      return 1
    fi
  fi

  if [[ $directory_output == "" ]] ; then
    directory_output="./"
  fi

  directory_generated="${directory_output}generated/"

  if [[ $get_help -eq 0 && $get_version -eq 0 ]] ; then
    if [[ ! -d $directory_output || ! -x $directory_output ]] ; then
      echo_error_out "The output directory '$c_n$directory_output$c_e' is not found, is not executable, or is not a directory."
      let failure=1
    fi

    if [[ ! -d $directory_generated || ! -x $directory_generated ]] ; then
      echo_error_out "The generated directory '$c_n$directory_generated$c_e' is not found, is not executable, or is not a directory."
      let failure=1
    fi

    if [[ $failure -eq 0 ]] ; then
      directory_generated="${directory_generated}$workflow/"
      if [[ ! -d $directory_generated ]] ; then
        mkdir $directory_generated

        if [[ $? -ne 0 ]] ; then
          echo_error_out "Failed to create the directory '$c_n$directory_generated$c_e'."
          let failure=1
        fi
      fi
    fi
  fi

  if [[ $get_help -eq 0 && $get_version -eq 0 ]] ; then
    if [[ $workflow == "" ]] ; then
      echo_error_out "No workflow is given."
      let failure=1
    fi

    workflow_file=${directory_input}workflows/${workflow}.fss

    if [[ ! -r $workflow_file ]] ; then
      echo_error_out "The workflow file '$c_n$workflow_file$c_e' is not found or is not readable."
      let failure=1
    fi
  fi

  if [[ $get_help -eq 1 ]] ; then
    print_help
    main_cleanup
    return 0
  fi

  if [[ $get_version -eq 1 ]] ; then
    print_version
    main_cleanup
    return 0
  fi

  if [[ $failure -eq 0 ]] ; then
    main_generate
    failure=$?
  fi

  if [[ $failure -eq 0 ]] ; then
    echo_out "Successfully Created Workflow '$workflow'."
    echo_out
  fi

  main_cleanup

  return $failure
}

main_generate() {

  if [[ ! -d $directory_generated ]] ; then
    mkdir -p $directory_generated

    if [[ $? -ne 0 ]] ; then
      echo_error_out "The generated directory '$c_n$directory_generated$c_e' could not be created."

      return 1
    fi
  fi

  if [[ ! -d ${directory_generated}nodes/ ]] ; then
    mkdir -p ${directory_generated}nodes/

    if [[ $? -ne 0 ]] ; then
      echo_error_out "The generated directory '$c_n${directory_generated}nodes/$c_e' could not be created."

      return 1
    fi
  fi

  check_exists_already "${directory_generated}workflow.json"
  if [[ $? -ne 0 ]] ; then return 1 ; fi

  load_workflow
  if [[ $? -ne 0 ]] ; then return 1 ; fi

  create_workflow
  return $?
}

# cleanup at end of program to prevent these functions from being available outside of the script.
main_cleanup() {
  unload_main_sh
  unload_basic_sh
  unload_json_sh
  unload_workflow_sh
}
