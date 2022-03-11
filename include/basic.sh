#!/bin/bash
# fw-generate script to be included.

unload_basic_sh() {

  unset echo_error
  unset echo_error_out
  unset echo_out
  unset echo_out1
  unset echo_out_e
  unset print_help
  unset check_exists_already
  unset unload_basic_sh
}

# Print an error message without extra leading and trailing newlines lines.
echo_error() {

  if [[ $output_mode -eq 0 || $output_mode -eq 1 ]] ; then
    echo -e "${c_e}ERROR: $1$c_r"
  fi
}

# Print an error message with extra leading and trailing newlines lines.
echo_error_out() {

  if [[ $output_mode -eq 0 || $output_mode -eq 1 ]] ; then
    echo
    echo -e "${c_e}ERROR: $1$c_r"
    echo
  fi
}

echo_out() {

  if [[ $output_mode -eq 0 ]] ; then
    echo "$1"
  fi
}

echo_out1() {

  if [[ $output_mode -eq 0 || $output_mode -eq 1 ]] ; then
    echo "$1"
  fi
}

echo_out_e() {

  if [[ $output_mode -eq 0 ]] ; then
    echo -e "$1"
  fi
}

print_help() {

  echo_out
  echo_out_e "${c_t}FW-Registry Workflow Generation Helper Script$c_r"
  echo_out_e "  ${c_n}Version $version$c_r"
  echo_out
  echo_out_e "Processes a workflow helper setting files from the workflows directory."
  echo_out_e "Utilizes the template files to generate a fw-registry compatible workflow structure of json files."
  echo_out
  echo_out_e "${c_h}Usage:$c_r"
  echo_out_e "  $c_i$script_pathname$c_r ${c_n}[${c_r}options${c_n}]${c_r} ${c_n}<${c_r}workflow${c_n}>${c_r}"
  echo_out
  echo_out_e "${c_h}Options:$c_r"
  echo_out_e " -${c_i}h${c_r}, --${c_i}help${c_r}              Print this help screen."
  echo_out_e " -${c_i}i${c_r}, --${c_i}input_directory${c_r}   Specify a custom input directory (currently: '$c_n$directory_input$c_r')."
  echo_out_e " -${c_i}o${c_r}, --${c_i}output_directory${c_r}  Specify a custom output directory (currently: '$c_n$directory_output$c_r')."
  echo_out_e " -${c_i}n${c_r}, --${c_i}no_color${c_r}          Do not apply color changes when printing output to screen."
  echo_out_e " -${c_i}s${c_r}, --${c_i}silent${c_r}            Do not print to the screen (specify once to allow for error output and twice to suppress error output)."
  echo_out_e " +${c_i}v${c_r}, ++${c_i}version${c_r}           Print the version number."
  echo_out
}

print_version() {

  echo_out "$version"
}

# Arguments:
#   1) The entire path to the file to check.
#   2) A context representing what kind of file this is (such as "workflow").
#
# Performs an existence check on the assumption that this is a file that cannot already exist.
check_exists_already() {
  local file="$1"
  local context="$2"
  local -i failure=0

  if [[ -f $file ]] ; then
    echo_error_out "The $context file '$c_n$file$c_e' already exists."

    let failure=1
  elif [[ -e $file && ! -f $file ]] ; then
    echo_error_out "The $context file '$c_n$file$c_e' already exists, but is not of type 'file'."

    let failure=1
  fi

  return $failure
}
