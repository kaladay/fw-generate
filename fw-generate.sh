#!/bin/bash
# license: gplv3.0 or greater.
#
# Program Requirements:
# - bash 4.x or higher.
# - coreutils that provides dirname (can be optional if include paths below are changed to hardcoded paths).
# - grep 3.x or higher (with PCRE support enabled).
# - fss_basic_list_read 0.5.4 or higher.
# - fss_extended_read 0.5.4 or higher.
# - fss_basic_read 0.5.4 or higher.
# - util-linux that provides uuidgen (should be optional if all workflows explicitly define UUIDs).
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
#
#   The "setup" (and json notation parts such as "setup.XXX") follow FSS-0000 (Basic).
#   To keep things simple, there is currently only support for a single depth structure.
#   This may be expanded on an as-needed basis.
#
#   The "triggers" represents the workflow triggers.
#   Each trigger is broken up into three FSS-0001 (Extended) parts:
#   - 1) Task Type: Represents name in templates/XXX.fss, with "templates/workflow.fss" being reserved for the workflow.
#   - 2) Machine Name: Distinctly represents the generated file name, such as "circ-fines/triggers/XXX.json" where "XXX" is the "machine name".
#   - 3) Human Name: Represents the name presented to the user and is placed as the "name" property in the generated json file.
#
#   The "tasks" represents the workflow "nodes".
#   Each task is broken up into three or four FSS-0001 (Extended) parts:
#   - 1) Task Type: Represents name in templates/XXX.fss, with "templates/workflow.fss" being reserved for the workflow.
#   - 2) Machine Name: Distinctly represents the generated file name, such as "circ-fines/nodes/XXX.json" where "XXX" is the "machine name".
#   - 3) Human Name: Represents the name presented to the user and is placed as the "name" property in the generated json file.
#   - 4) UUID: Represents an optional UUID to represent as the ID. This supercedes any ID specified within the "machine name" list for this task.
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
#   This works well but because of maps and arrays, the design can be slightly akward in this regard.
#   The json map and json array are represented as Objects containing a "." just like is described in the workflow documentation above.
#   These "setup.XXX" forms require an initialization property immediately before it and all array/map parts must follow after it, such as:
#     # fss-0000
#     active false
#     setup {}
#     setup.asyncBefore false
#     setup.asyncAfter false
#     initialContext {}
#
# Operation:
#   This is a templating system in which is used to more easily write and generate the workflow json files while avoiding all of the back and forth as well as repitition.
#
#   The "settings" Object, any "settings." javascript notation Objects, and the "tasks" are used to generate the main workflow file, such as: "generated/circ-fines/workflow.json".
#
#   To achieve this, the program will:
#   - 1) automatically generate UUIDs for each task and trigger.
#   - 2) load the template and then append the overrides for each task and trigger.
#   - 3) create the setup file, such as: "genenrated/circ-fines/setup.json".
#   - 4) create the workflow file from the tasks and the settings file, such as: "generated/circ-fines/workflow.json".
#   - 5) each task and trigger will be saved, such as: "generated/circ-fines/nodes/start.json" or "generated/circ-fines/triggers/startTrigger.json".
#
# Notes:
#   The overrides only need to be populated if there is some need or there is no default value in the template.
#   This avoids unecessary typing and redundancy.
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

source $(dirname $0)/include/main.sh
source $(dirname $0)/include/basic.sh
source $(dirname $0)/include/json.sh
source $(dirname $0)/include/template.sh
source $(dirname $0)/include/workflow.sh

# this uses $@ in quotes to preserve whitespace in each parameter passed to the script and prevent them from being expanded into different parameters.
main "$@"
