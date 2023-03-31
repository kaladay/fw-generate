#!/bin/bash
#
# An fw-generate script intended to be included by the main script file (usually fw-generate.sh).
#

unload_main_sh() {

  unset main
  unset main_generate
  unset main_handle_colors
  unset main_cleanup
  unset unload_main_sh
}

main() {

  if [[ $SHELL_ENGINE == "zsh" ]] ; then
    emulate ksh
  fi

  # Standard main parameters.
  local script_pathname=$0
  local do_color="dark"
  local grab_next=
  local extra_parameters=
  local version="0.1.0"
  local -i get_help=0
  local -i get_version=0
  local -i parameters_total=$#
  local -i extra_parameters_total=0
  local -i failure=0
  local -i verbosity=2 # 0 = quiet, 1 = error, 2 = normal, 3 = verbose, 4 = debug.

  # Generic.
  local -i i=0
  local j=
  local p=

  # Codes: reset, title, error, warning, highlight, notice, important, subtle, and prefix.
  local c_r=
  local c_t=
  local c_e=
  local c_w=
  local c_h=
  local c_n=
  local c_i=
  local c_s=
  local c_p=

  # Program variables.
  local command=
  local directory_input="./"
  local directory_output="./"
  local directory_generated=

  local workflow=
  local workflow_file=
  local workflow_objects=
  local workflow_tasks=

  # Valid types: "string", "literal", "null", "array", "map".
  local -A workflow_settings=()
  local -A workflow_settings_type=()

  local -a tasks_task=()
  local -a tasks_machine=()
  local -a tasks_human=()
  local -a tasks_uuid=()
  local -a tasks_template=()
  local -i tasks_total=0

  if [[ ${parameters_total} -gt 0 ]] ; then
    while [[ ${i} -lt ${parameters_total} ]] ; do

      let i++

      if [[ $SHELL_ENGINE == "zsh" ]] ; then
        p="${(P)i}"
      else
        p="${!i}"
      fi

      if [[ ${grab_next} == "" ]] ; then
        if [[ ${p} == "-h" || ${p} == "--help" ]] ; then
          let get_help=1
        elif [[ ${p} == "+d" || ${p} == "++dark" ]] ; then
          do_color="dark"
        elif [[ ${p} == "+l" || ${p} == "++light" ]] ; then
          do_color="light"
        elif [[ ${p} == "+n" || ${p} == "++no_color" ]] ; then
          do_color="none"
        elif [[ ${p} == "+Q" || ${p} == "++quiet" ]] ; then
          let verbosity=0
        elif [[ ${p} == "+E" || ${p} == "++error" ]] ; then
          let verbosity=1
        elif [[ ${p} == "+N" || ${p} == "++normal" ]] ; then
          let verbosity=2
        elif [[ ${p} == "+V" || ${p} == "++verbose" ]] ; then
          let verbosity=3
        elif [[ ${p} == "+D" || ${p} == "++debug" ]] ; then
          let verbosity=4
        elif [[ ${p} == "-i" || ${p} == "--input_directory" ]] ; then
          grab_next="input_directory"
        elif [[ ${p} == "-o" || ${p} == "--output_directory" ]] ; then
          grab_next="output_directory"
        elif [[ ${workflow} == "" ]] ; then
          workflow="${p}"
        elif [[ ${p} == "+v" || ${p} == "++version" ]] ; then
          let get_version=1
        else
          extra_parameters[${extra_parameters_total}]=${p}
          let extra_parameters_total++
        fi
      else
        if [[ ${grab_next} == "input_directory" ]] ; then

          # Use grep to avoid needing something like awk or sed, but this simple strategy cannot handle directories with only white space in their names"
          grab_next=$(echo "${p}" | grep -sPo '[^/]+')

          if [[ ${grab_next} == "" ]] ; then
            directory_input=
          else
            for j in ${grab_next} ; do
              if [[ ${j} != "." ]] ; then
                directory_input=/
              fi

              break
            done

            for j in ${grab_next} ; do
              directory_input="${directory_input}${j}/"
            done
          fi

          grab_next=
        elif [[ ${grab_next} == "output_directory" ]] ; then

          # Use grep to avoid needing something like awk or sed, but this simple strategy cannot handle directories with only white space in their names"
          grab_next=$(echo "${p}" | grep -sPo '[^/]+')

          if [[ ${grab_next} == "" ]] ; then
            directory_output=
          else
            for j in ${grab_next} ; do
              if [[ ${j} != "." ]] ; then
                directory_output=/
              fi

              break
            done

            for j in ${grab_next} ; do
              directory_output="${directory_input}${j}/"
            done
          fi
          grab_next=
        else
          break
        fi
      fi
    done
  fi

  main_handle_colors

  if [[ ${get_help} -eq 1 ]] ; then
    print_help
    main_cleanup

    return 0
  fi

  if [[ ${get_version} -eq 1 ]] ; then
    print_version
    main_cleanup

    return 0
  fi

  if [[ ! -d ${directory_input} || ! -x ${directory_input} ]] ; then
    echo_error_out "The input directory '${c_n}${directory_input}${c_e}' is not found, is not executable, or is not a directory."

    return 1
  fi

  if [[ ! -d ${directory_input}templates || ! -x ${directory_input}templates ]] ; then
    echo_error_out "The templates directory '${c_n}${directory_input}templates${c_e}' is not found, is not executable, or is not a directory."

    return 1
  fi

  if [[ ! -d ${directory_input}workflows || ! -x ${directory_input}workflows ]] ; then
    echo_error_out "The templates directory '${c_n}${directory_input}workflows${c_e}' is not found, is not executable, or is not a directory."

    return 1
  fi

  if [[ ${directory_input} == "" ]] ; then
    directory_input="./"
  fi

  if [[ ${directory_output} == "" ]] ; then
    directory_output="./"
  fi

  if [[ ${workflow} == "" ]] ; then
    echo_error_out "No workflow is given."

    if [[ ${verbosity} -gt 0 ]] ; then
      echo_out_e "${c_e}The following workflows are available (under ${c_n}${directory_input}workflows/${c_e}):${c_r}"

      for j in ${directory_input}workflows/*.fss ; do

        if [[ ${j} == "${directory_input}workflows/*.fss" ]] ; then continue ; fi

        echo_out "  - $(echo "${j}" | grep -sPo '[^/]+(?=\.fss)')"
      done

      echo_out
    fi

    let failure=1
  fi

  if [[ ${failure} -eq 0 ]] ; then
    workflow_file=${directory_input}workflows/${workflow}.fss

    if [[ ! -r ${workflow_file} ]] ; then
      echo_error_out "The workflow file '${c_n}${workflow_file}${c_e}' is not found or is not readable."
      let failure=1
    fi
  fi

  directory_generated="${directory_output}generated/"

  if [[ ${failure} -eq 0 && -e ${directory_generated} && ( ! -d ${directory_generated} && ! -x ${directory_generated} ) ]] ; then
    echo_error_out "The output directory '${c_n}${directory_output}${c_e}' is found but is not executable or is not a directory."
    let failure=1
  fi

  if [[ ${failure} -eq 0 ]] ; then
    directory_generated="${directory_generated}${workflow}/"
    if [[ ! -d ${directory_generated} ]] ; then
      mkdir -p ${directory_generated}

      if [[ $? -ne 0 ]] ; then
        echo_error_out "Failed to create the directory '${c_n}${directory_generated}${c_e}'."
        let failure=1
      fi
    fi
  fi

  if [[ ${failure} -eq 0 ]] ; then
    main_generate
    let failure=$?
  fi

  if [[ ${failure} -eq 0 ]] ; then
    echo_out "Successfully Created Workflow '${workflow}'."
    echo_out
  fi

  main_cleanup

  return ${failure}
}

main_generate() {

  if [[ ! -d ${directory_generated} ]] ; then
    mkdir -p ${directory_generated}

    if [[ $? -ne 0 ]] ; then
      echo_error_out "The generated directory '${c_n}${directory_generated}${c_e}' could not be created."

      return 1
    fi
  fi

  if [[ ! -d ${directory_generated}nodes/ ]] ; then
    mkdir -p ${directory_generated}nodes/

    if [[ $? -ne 0 ]] ; then
      echo_error_out "The generated directory '${c_n}${directory_generated}nodes/${c_e}' could not be created."

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

main_handle_colors() {

  if [[ ${do_color} == "light" ]] ; then
    c_r="\\033[0m"
    c_t="\\033[1;34m"
    c_e="\\033[1;31m"
    c_w="\\033[0;31m"
    c_h="\\033[0;34m"
    c_n="\\033[0;01m"
    c_i="\\033[0;35m"
    c_s="\\033[1;30m"
    c_p="\\"
  elif [[ ${do_color} == "dark" ]] ; then
    c_r="\\033[0m"
    c_t="\\033[1;33m"
    c_e="\\033[1;31m"
    c_w="\\033[0;33m"
    c_h="\\033[1;49;36m"
    c_n="\\033[0;01m"
    c_i="\\033[0;49;36m"
    c_s="\\033[1;30m"
    c_p="\\"
  elif [[ ${do_color} == "none" ]] ; then
    c_r=
    c_t=
    c_e=
    c_w=
    c_h=
    c_n=
    c_i=
    c_s=
    c_p=
  fi
}

# cleanup at end of program to prevent these functions from being available outside of the script.
main_cleanup() {

  unload_main_sh
  unload_basic_sh
  unload_json_sh
  unload_workflow_sh
}
