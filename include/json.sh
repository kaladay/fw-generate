#!/bin/bash
# fw-generate script to be included.

unload_json_sh() {
  unset prepare_json_line
  unset prepare_json_line_array_or_map_end
  unset populate_json_line
  unset write_json_file
  unset detect_if_unquoted_number
  unset unload_json_sh
}

# Arguments:
#   1) depth: Number represents depth within the json structure (each number represens two spaces).
#             -1 or less designates that this is an map or an array.
#             -2 or less represents that the depth for an map or array is "abs(#) - 1" such that "#" represents the number (like -2).
#   2) property: The property "key".
#             Property must be an empty string when this represents an "array" type.
#   3) value: The property "value".
#             If this exactly matches "null", "true", or "false", the value is to be printed without double quotes.
#             If this represents a valid integer, then this value is to be printed without double quotes.
#
# The variables "depths", "properties", "values", and "total" are expected to be defined prior to calling this.
prepare_json_line() {
  local -i depth=$1
  local property="$2"
  local value="$3"
  local result=

  if [[ $depth -eq -1 ]] ; then
    properties["$total"]="\"$property\""

    if [[ $value == "map" ]] ; then
      values["$total"]="{"
    elif [[ $value == "array" ]] ; then
      values["$total"]="["
    elif [[ $value == "empty-map" ]] ; then
      values["$total"]="{}"
    elif [[ $value == "empty-array" ]] ; then
      values["$total"]="[]"
    fi
  else
    if [[ $property == "" ]] ; then
      properties["$total"]=
    else
      detect_if_unquoted_number "$property"

      if [[ $result == "" ]] ; then
        properties["$total"]="\"$property\""
      else
        properties["$total"]="$result"
      fi
    fi

    if [[ $value == "true" || $value == "false" || $value == "null" || $(echo -n "$value" | grep -sPo "^\"") == "\"" || $value == "{}" || $value == "[]" ]] ; then
      values["$total"]="$value"
    else
      detect_if_unquoted_number "$value"

      if [[ $result == "" ]] ; then
        values["$total"]="\"$value\""
      else
        values["$total"]="$result"
      fi
    fi
  fi

  if [[ $depth -lt 0 ]] ; then
    let depth=0-$depth
    let depth--
  fi

  depths["$total"]="$depth"
  let total++

  return 0
}

# Arguments:
#   1) The depth as described here: prepare_json_line()
#   2) The type: either "map" or "array".
#
# This is used to designate the end of an array or map for the purposes of not printing the final ",".
#
# The variables "depths", "properties", "values", and "total" are expected to be defined prior to calling this.
prepare_json_line_array_or_map_end() {
  local -i depth=$1
  local type="$2"

  if [[ $depth -lt 0 ]] ; then
    let depth=0-$depth
    let depth--

    if [[ $type == "map" ]] ; then
      depths["$total"]=$depth
      properties["$total"]="map"
      values["$total"]="}"
    elif [[ $type == "array" ]] ; then
      depths["$total"]=$depth
      properties["$total"]="array"
      values["$total"]="]"
    else
      depths["$total"]=$depth
    fi

    let total++
  fi

  return 0
}

populate_json_line() {
  local index="$1"
  local file="$2"
  local -i last="$3"
  local -i next=0
  local -i depth=${depths["$index"]}
  local property=${properties["$index"]}
  local value=${values["$index"]}
  local end=

  if [[ $last -eq 0 ]] ; then
    end=","
  fi

  if [[ $depth -eq 0 ]] ; then
    echo -n "  " >> $file
  elif [[ $depth -eq 1 ]] ; then
    echo -n "    " >> $file
  fi

  if [[ $value == "{" || $value == "[" ]] ; then
    end=
  fi

  let next=$index+1
  if [[ $next -lt $total ]] ; then
    let next=${depths["$next"]}
    if [[ $next -ne $depth ]] ; then
      end=
    fi
  fi

  if [[ $value == "}" || $value == "]" || $property == "" ]] ; then
    echo "$value$end" >> $file
  else
    echo "$property: $value$end" >> $file
  fi

  return $?
}

# Arguments:
#   1) The filepath to write to.
#
# The variables "depths", "properties", "values", "total" are expected to be defined prior to calling this.
write_json_file() {
  local file="$1"
  local -i last=0
  local -i i=0
  local previous=
  local -i failure=0

  echo "{" > "$file"
  failure=$?

  while [[ $i -lt $total && $failure -eq 0 ]] ; do

    let last=$i+1
    if [[ $last -eq $total ]] ; then
      let last=1
    else
      let last=0
    fi

    populate_json_line $i "$file" $last
    failure=$?

    let i++
  done

  if [[ $failure -eq 0 ]] ; then
    echo "}" >> $file
    failure=$?
  fi

  if [[ $failure -eq 1 ]] ; then
    echo_error_out "Failed to create '$c_n$file$c_e'."

    return 1
  fi

  echo_out "- Created: $file"
  echo_out

  return 0
}

# Arguments:
# 1) A string to potentially convert into an unquoted number, or into a quoted number.
#
# Detect unquoted number.
# The caller must have "result" available in its scope.
detect_if_unquoted_number() {
  local input="$1"
  result=

  if [[ $(echo -n "$input" | grep -sPo "^\s*(\d+|\d+\.\d+)\s*$") == "" ]] ; then
    return 0
  fi

  result=$(echo -n "$input" | grep -sPo "\d+\.\d+")

  if [[ $result == "" ]] ; then
    result=$(echo -n "$input" | grep -sPo "\d+")
  fi

  return 0
}
