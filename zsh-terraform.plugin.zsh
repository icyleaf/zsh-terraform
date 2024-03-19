#!/bin/zsh
# Terraform plugin for zsh
#
# Author : Patrick Tavares <tavarespatrick01@gmail.com>
#

################################################################################
# COMMONS
################################################################################
autoload colors is-at-least

################################################################################
# CONSTANT
################################################################################
BOLD="bold"
NONE="NONE"
API_GITUB=https://api.github.com/repos
TF_DOCS_RELEASE=terraform-docs/terraform-docs/releases
TF_TRIVY_RELEASE=aquasecurity/trivy/releases
TF_LINT_RELEASE=terraform-linters/tflint/releases
TF_AUTO_MV_RELEASE=busser/tfautomv/releases

# Local plugin directory
[[ -z "${ZSH_TF_TOOLS_HOME}" ]] && export ZSH_TF_TOOLS_HOME="${HOME}/.terraform-tools"
# Local file to store tools version
ZSH_TF_DOCS_VERSION_FILE=${ZSH_TF_TOOLS_HOME}/version_tfdocs.txt
ZSH_TF_TRIVY_VERSION_FILE=${ZSH_TF_TOOLS_HOME}/version_trivy.txt
ZSH_TF_LINT_VERSION_FILE=${ZSH_TF_TOOLS_HOME}/version_tflint.txt
ZSH_TF_AUTO_MV_VERSION_FILE=${ZSH_TF_TOOLS_HOME}/version_tfautomv.txt

################################################################################
# Install tools Functions
################################################################################

# ------------------------------------------------------------------------------
# Log
# ------------------------------------------------------------------------------
_zsh_terraform_log() {
  local font=$1
  local color=$2
  local msg=$3

  if [ $font = $BOLD ]
  then
    echo $fg_bold[$color] "[zsh-terraform-plugin] $msg" $reset_color
  else
    echo $fg[$color] "[zsh-terraform-plugin] $msg" $reset_color
  fi
}

# ------------------------------------------------------------------------------
# Retrieve last tool version
# ------------------------------------------------------------------------------
_zsh_terraform_last_version() {
  local tool=$1
  echo $(curl -s ${API_GITUB}/${tool}/latest | grep tag_name | cut -d '"' -f 4)
}

# ------------------------------------------------------------------------------
# Download and install tools
# ------------------------------------------------------------------------------
_zsh_terraform_download_install() {
   local toolName=$1
   local version=$2
   local destDir=$3
   local url
   local machine
    case "$(uname -m)" in
      x86_64)
        machine=amd64
        # if on Darwin, set $OSTYPE to match the release
        [[ "$OSTYPE" == "darwin"* ]] && local uname -m=macos
        ;;
      *)
        _zsh_terraform_log $BOLD "red" "Machine $(uname -m) not supported by this plugin"
        return 1
    ;;
    esac
   _zsh_terraform_log $NONE "blue" "  -> Download and install ${toolName} ${version}"
   case ${toolName} in
    tfdocs)
      curl -o "${destDir}/tmp.tar.gz" -fsSL https://github.com/${TF_DOCS_RELEASE}/download/${version}/terraform-docs-${version}-${OSTYPE%-*}-${machine}.tar.gz || (_zsh_terraform_log $BOLD "red" "Error while downloading terraform-docs release" ; return)
      tar xzf ${destDir}/tmp.tar.gz -C ${destDir} 2>&1 > /dev/null
      rm -rf ${destDir}/*.tar.gz
      echo ${version} > ${ZSH_TF_DOCS_VERSION_FILE}
      ;;
    trivy)
      [[ "$OSTYPE" == "darwin"* ]] && local OS=macOS
      [[ "$OSTYPE" == "linux"* ]] && local OS=Linux
      [[ "$machine" == "amd64" ]] && local machine="64bit"
      curl -o "${destDir}/tmp.tar.gz" -fsSL https://github.com/${TF_TRIVY_RELEASE}/download/${version}/trivy_${version:1}_${OS}-${machine}.tar.gz || (_zsh_terraform_log $BOLD "red" "Error while downloading terraform trivy release" ; return)
      tar xzf ${destDir}/tmp.tar.gz -C ${destDir} 2>&1 > /dev/null
      rm -rf ${destDir}/*.tar.gz
      echo ${version} > ${ZSH_TF_TRIVY_VERSION_FILE}
      ;;
    tflint)
      curl -o "${destDir}/tmp.zip" -fsSL https://github.com/${TF_LINT_RELEASE}/download/${version}/tflint_${OSTYPE%-*}_${machine}.zip || (_zsh_terraform_log $BOLD "red" "Error while downloading terraform-linters release" ; return)
      unzip -o ${destDir}/tmp.zip -d ${destDir} 2>&1 > /dev/null
      rm -rf ${destDir}/tmp.zip
      echo ${version} > ${ZSH_TF_LINT_VERSION_FILE}
      ;;
    tfautomv)
      curl -o "${destDir}/tmp.tar.gz" -fsSL https://github.com/${TF_AUTO_MV_RELEASE}/download/${version}/tfautomv_${version:1}_${OSTYPE%-*}_${machine}.tar.gz || (_zsh_terraform_log $BOLD "red" "Error while downloading tfautomv release" ; return)
      tar xzf ${destDir}/tmp.tar.gz -C ${destDir} 2>&1 > /dev/null
      rm -rf ${destDir}/tmp.tar.gz
      echo ${version} > ${ZSH_TF_AUTO_MV_VERSION_FILE}
      ;;
    *)
      _zsh_terraform_log $BOLD "red" "Unknown tool"
      return 1
  esac
  _zsh_terraform_log $BOLD "green" "  -> Install OK for ${toolName} at version ${version}"
}

# ------------------------------------------------------------------------------
# Install all tools
# ------------------------------------------------------------------------------
_zsh_terraform_install_tool() {
  local tool=$1
  local releaseURL=$2
  _zsh_terraform_log $BOLD "blue" "   --> ${tool} <--"
  mkdir -p ${ZSH_TF_TOOLS_HOME}/${tool} || _zsh_terraform_log $NONE "green" "dir already exist"
  local last_version=$(_zsh_terraform_last_version ${releaseURL})
  _zsh_terraform_log $NONE "blue" "-> retrieve last version of ${tool}..."
  _zsh_terraform_download_install ${tool} ${last_version} ${ZSH_TF_TOOLS_HOME}/${tool}
}

_zsh_terraform_install() {
  _zsh_terraform_log $NONE "blue" "#############################################"
  _zsh_terraform_log $BOLD "blue" "Installing Terraform tools..."
  _zsh_terraform_log $NONE "blue" "-> Creating Terraform tools home dir : ${ZSH_TF_TOOLS_HOME}"
  mkdir -p ${ZSH_TF_TOOLS_HOME} || _zsh_terraform_log $NONE "green" "dir already exist"
  # Install tfdocs
  _zsh_terraform_install_tool "tfdocs" ${TF_DOCS_RELEASE}
  # Install trivy
   _zsh_terraform_install_tool "trivy" ${TF_TRIVY_RELEASE}
  # Install tflint
   _zsh_terraform_install_tool "tflint" ${TF_LINT_RELEASE}
   # Install tfautomv
    _zsh_terraform_install_tool "tfautomv" ${TF_AUTO_MV_RELEASE}
  _zsh_terraform_log $NONE "blue" "#############################################"
}

# ------------------------------------------------------------------------------
# Update all tools
# ------------------------------------------------------------------------------
_update_zsh_terraform_tool() {
  local tool=$1
  local releaseFile=$2
  local releaseURL=$3

  local current_version=$(cat ${releaseFile})
  local last_version=$(_zsh_terraform_last_version ${releaseURL})

  if is-at-least ${last_version#v*} ${current_version#v*}
    then
      _zsh_terraform_log $NONE "blue" "-> Checking ${tool}..."
      _zsh_terraform_log $BOLD "green" "Already up to date, current version : ${current_version}"
    else
      _zsh_terraform_log $NONE "blue" "-> Updating ${tool}..."
      _zsh_terraform_install_tool ${tool} ${releaseURL}
      _zsh_terraform_log $BOLD "green" "Update OK"
    fi
}

update_zsh_terraform() {
  _zsh_terraform_log $NONE "blue" "#############################################"
  _zsh_terraform_log $BOLD "blue" "Checking new version of Terraform tools..."
   # Update tfdocs
  _update_zsh_terraform_tool "tfdocs" ${ZSH_TF_DOCS_VERSION_FILE} ${TF_DOCS_RELEASE}
  # Update trivy
  _update_zsh_terraform_tool "trivy" ${ZSH_TF_TRIVY_VERSION_FILE} ${TF_TRIVY_RELEASE}
  # Update tflint
  _update_zsh_terraform_tool "tflint" ${ZSH_TF_LINT_VERSION_FILE} ${TF_LINT_RELEASE}
  # Update tfautomv
  _update_zsh_terraform_tool "tfautomv" ${ZSH_TF_AUTO_MV_VERSION_FILE} ${TF_AUTO_MV_RELEASE}
  _zsh_terraform_log $NONE "blue" "#############################################"
}

################################################################################
# From original terraform plugin
################################################################################
function tf_prompt_info() {
  # dont show 'default' workspace in home dir
  [[ "$PWD" != ~ ]] || return
  # check if in terraform dir and file exists
  [[ -d .terraform && -r .terraform/environment ]] || return

  local workspace="$(< .terraform/environment)"
  echo "${ZSH_THEME_TF_PROMPT_PREFIX-[}${workspace:gs/%/%%}${ZSH_THEME_TF_PROMPT_SUFFIX-]}"
}

################################################################################
# Define all lower levels aliases
################################################################################
alias tf='terraform'
alias tff='tf fmt'
alias tfv='tf validate'
alias tfi='tf init'
alias tfp='tf plan'
alias tfa='tf apply'
alias tfd='tf destroy'
alias tfo='tf output'
alias tfr='tf refresh'
alias tfs='tf show'
alias tfw='tf workspace'

################################################################################
# All others aliases
################################################################################
# Basics
alias tffr='tff -recursive'
alias tfip='tfi && tfp'
alias tfia='tfi && tfa'
alias tfid='tfi && tfd'
# Warning : with auto-approuve
alias tfa!='tfa -auto-approve'
alias tfia!='tfi && tfa!'
alias tfd!='tfd -auto-approve'
alias tfid!='tfi && tfd!'
# Utils
alias tfversion='tf version'

################################################################################
# Custom function
################################################################################

# ------------------------------------------------------------------------------
# Terraform workspace initializer
# ------------------------------------------------------------------------------
function tfws() {
    if (( $# != 1 ))
      then
        echo "> Usage:  $0 [workspace_name]"
    else
        count=$(find $PWD -maxdepth 1 -type f -name '*.tf' | wc -l)
        if (( $count <= 0 ))
          then
            echo "> Not in terraform directory"
        else
            tfw select "$1" || tfw new "$1"
        fi
    fi
}

# ------------------------------------------------------------------------------
# Install and load terraform tools
# ------------------------------------------------------------------------------
_zsh_terraform_load_tool() {
    # export PATH if needed
    local -r plugin_dir=$1
    # Add the plugin bin directory path if it doesn't exist in $PATH.
    if [[ -z ${path[(r)$plugin_dir]} ]]; then
        path+=($plugin_dir)
    fi
}

_zsh_terraform_load() {
    # export PATH
    _zsh_terraform_load_tool ${ZSH_TF_TOOLS_HOME}/tfdocs
    _zsh_terraform_load_tool ${ZSH_TF_TOOLS_HOME}/trivy
    _zsh_terraform_load_tool ${ZSH_TF_TOOLS_HOME}/tflint
    _zsh_terraform_load_tool ${ZSH_TF_TOOLS_HOME}/tfautomv
}

# install terraform and all tools if it isn't already installed
[[ "$(ls -1 ${ZSH_TF_TOOLS_HOME}/version_*.txt  2>/dev/null | wc -l)" -eq 0 ]] && _zsh_terraform_install


# load terraform and all tools if it is installed
[[ "$(ls -1 ${ZSH_TF_TOOLS_HOME}/version_*.txt  2>/dev/null | wc -l)" -gt 0 ]] && _zsh_terraform_load

unset -f _zsh_terraform_install _zsh_terraform_load _zsh_terraform_load_tool
