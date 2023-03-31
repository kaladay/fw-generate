#!/bin/bash
# license: gplv3.0 or greater.
#
# Program Requirements:
#   - bash 4.x or higher.
#   - grep 3.x or higher (with PCRE support enabled).
#   - fss_basic_list_read 0.6.z, for any z > 3.
#   - fss_extended_read 0.6.z, for any z > 3.
#   - fss_basic_read 0.6.z, for any z > 3.
#
# Optional Dependencies:
#   - Something that provides the "dirname" program, such as coreutils.
#   - Something that provides "uuidgen", such as util-linux, (optional only if all workflows explicitly define UUIDs).
#
# Conditional Dependencies:
#   - If bash is not available, zsh is supported (zsh 5.8 is known to work).
#     - To achieve zsh support, set SHELL_ENGINE to "zsh", such as "SHELL_ENGINE=zsh ./fw-generate.sh --help".
#
# This script is meant to be operated within the directory that it creates the templates and will also expect any individual parts to reside within there (include files, templates, etc..).
#
# Workflows:
#   "settings", "setup", "tasks", and "triggers" are reserved.
#   The "settings" are the workflow settings being overwritten (based on the templates/workflow.fss).
#   The "tasks" represents the tasks to be executed.
#
#   The UUID is to be generated automatically so that we do not have to deal with them.
#   The FSS-0002 (Basic List) standard doesn't support nested structures, so the Object names will utilize the javascript "." notation for designating a property within a map.
#
#   The "settings" (and json notation parts such as "settings.setup") follow FSS-0000 (Basic).
#   If the Object "id" (within "settings") is not specified or is specified with no Content, then the "id" is created using a generated UUID.
#
#   Settings specified in a workflow may override the same named Object specified within the template.
#   As an exception to this is if the template includes an object or an array (via '{}' or '[]') and the settings only uses the dot notation ('setting.XXX') then those values are appended.
#   An explicit '{}' or '[]' in the settings would override the same named Object specified within the template.
#
#   The "setup" (and json notation parts such as "setup.XXX") follow FSS-0000 (Basic).
#   To keep things simple, there is currently only support for a single depth structure.
#   This may be expanded on an as-needed basis.
#
#   The "triggers" represents the workflow triggers.
#   Each trigger is broken up into three FSS-0001 (Extended) parts:
#     - 1) Task Type: Represents name in templates/XXX.fss, with "templates/workflow.fss" being reserved for the workflow.
#     - 2) Machine Name: Distinctly represents the generated file name, such as "circ-fines/triggers/XXX.json" where "XXX" is the "machine name".
#     - 3) Human Name: Represents the name presented to the user and is placed as the "name" property in the generated json file.
#
#   The "tasks" represents the workflow "nodes".
#   Each task is broken up into three or four FSS-0001 (Extended) parts:
#     - 1) Task Type: Represents name in templates/XXX.fss, with "templates/workflow.fss" being reserved for the workflow.
#     - 2) Machine Name: Distinctly represents the generated file name, such as "circ-fines/nodes/XXX.json" where "XXX" is the "machine name".
#     - 3) Human Name: Represents the name presented to the user and is placed as the "name" property in the generated json file.
#     - 4) UUID: Represents an optional UUID to represent as the ID. This supersedes any ID specified within the "machine name" list for this task.
#
#   The "start" and "stop" tasks are automatically created but can be modified using "start" and "stop" "machine names".
#   The top-level "start" and "stop" tasks are named exactly that but for any subprocess (whose tasks are named "tasks-XXX") the start and stop will be named "XXXStart" and "XXXStop", where XXX is the sub-process "machine name".
#
#   Each FSS-0002 Object name other than the reserved ones "settings" and "tasks" are representations of the "machine name" as specified in each task.
#   The Content of these FSS-0002 (Basic List) Objects represent the overrides and also utilize the javascript "." notation for designating a property within a map.
#   The FSS-0002 Content follow FSS-0000 (Basic).
#
#   For simplicity of design "triggers" and "tasks" utilize the same namespace and therefore a "trigger" may not have the same machine name as a "task".
#
# Templates:
#   In addition to the main workflow file there are templates.
#   Templates provide default properties and values to insert on a per-type basis and are stored in the templates directory.
#   The types include the reserved "workflow.fss" as well as any valid node type, such as "databaseQueryTask.fss".
#
#   The templates are meant to be as simple as possible and so they only follow FSS-0000 (Basic).
#   This works well but because of maps and arrays, the design can be slightly awkward in this regard.
#   The json map and json array are represented as Objects containing a "." just like is described in the workflow documentation above.
#   These "setup.XXX" forms require an initialization property immediately before it and all array/map parts must follow after it, such as:
#     # fss-0000
#     active false
#     setup {}
#     setup.asyncBefore false
#     setup.asyncAfter false
#     initialContext {}
#
#   Template values that specify arrays and maps are:
#     - '[]': Represents an array.
#     - '{}': Represents a map.
#
#   Once an array or a map is defined, then values may be appended.
#     - '.': is appended at the end of an array (does not have non-white space on the immediate right of the period).
#     - '.XXX': is appended at the end of a map where 'XXX' is used to represent some arbitrary map name (the map name must not contain white space).
#
#   Special syntax handling for NULL, string, and digits are as follows.
#     - To use a literal {} or [], enclose them in either single-quotes or double quotes, such as: '{}' or "{}".
#     - The use of single and double quotes (or lack thereof) is preserved for all other cases (for example "deploymentId null" becomes "deploymentId: null," and "deploymentId 'null'" becomes "deploymentId: 'null',").
#     - When no value is specified, then an empty string using double quotes is used (for example "description" becomes "description: "",").
#
#   The order in which the JSON structure is generated follows the order of the template first and then all new Objects are appended to the JSON.
#   Any Object that overrides or appends to an Object defined within the template are replaced or appended to in place rather than appended to the JSON.
#
# Operation:
#   This is a templating system in which is used to more easily write and generate the workflow json files while avoiding all of the back and forth as well as repitition.
#
#   The "settings" Object, any "settings." javascript notation Objects, and the "tasks" are used to generate the main workflow file, such as: "generated/circ-fines/workflow.json".
#
#   To achieve this, the program will:
#     - 1) Automatically generate UUIDs for each task and trigger.
#     - 2) Load the template and then append the overrides for each task and trigger.
#     - 3) Create the setup file, such as: "generated/circ-fines/setup.json".
#     - 4) Create the workflow file from the tasks and the settings file, such as: "generated/circ-fines/workflow.json".
#     - 5) Each task and trigger will be saved, such as: "generated/circ-fines/nodes/start.json" or "generated/circ-fines/triggers/startTrigger.json".
#
# Notes:
#   The overrides only need to be populated if there is some need or there is no default value in the template.
#   This avoids unnecessary typing and redundancy.
#
#   This does nothing with javascript files.
#
#   @todo a "subprocess" needs special handling in a task, possibly have it as "subprocess XXX" in tasks and then as "tasks.XXX" in its own list.
#         This should handle the "connectTo", "MoveTo", and other similar designs.
#
#   The FSS allow for spaces in the Object names, but to keep things simple this program requires that no spaces or special characters.
#   The names should only be word-characters, "-", "+", or ".".
#   Whereas "." is specifically used to designated an array or map within in a JSON-like manner.
#

if [[ $(type -p dirname) == "" ]] ; then
  source include/main.sh
  source include/basic.sh
  source include/json.sh
  source include/template.sh
  source include/workflow.sh
else
  source $(dirname $0)/include/main.sh
  source $(dirname $0)/include/basic.sh
  source $(dirname $0)/include/json.sh
  source $(dirname $0)/include/template.sh
  source $(dirname $0)/include/workflow.sh
fi

# This uses $@ in quotes to preserve white space in each parameter passed to the script and prevent them from being expanded into different parameters.
main "$@"
