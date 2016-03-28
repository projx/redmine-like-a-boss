#!/bin/sh
#
##/usr/bin/env bash


#check for:

#wget
#unzip
#git
#rake
#bundle
#realpath


if ! command -v rake > /dev/null 2>&1 ; then
	echo "binary 'rake' not found but required."
	exit 1
fi
if ! command -v bundle > /dev/null 2>&1 ; then
	echo "binary 'bundle' not found but required."
	exit 1
fi
if ! command -v realpath > /dev/null 2>&1 ; then
	echo "binary 'realpath' not found but required."
	exit 1
fi


DIR_BASE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
DIR_REDMINE="${DIR_BASE}/redmine"
DIR_REDMINE_PLUGINS="${DIR_BASE}/redmine-plugins"
DIR_REDMINE_THEMES="${DIR_BASE}/redmine-themes"


# Ask a yes/no question and read users choise
#
# @param        string  Question to ask
# @param        string  Default 'Y' or 'N'
# @return       int             1: yes | 0:no
_ask() {
	question=$1

	while true; do

		if [ "${2:-}" = "Y" ]; then
			prompt="$(tput setaf 3)Y$(tput sgr0)/$(tput setaf 3)n$(tput sgr0)"
			default=Y
		elif [ "${2:-}" = "N" ]; then
			prompt="$(tput setaf 3)y$(tput sgr0)/$(tput setaf 3)N$(tput sgr0)"
			default=N
		else
			prompt="$(tput setaf 3)y$(tput sgr0)/$(tput setaf 3)n$(tput sgr0)"
			default=
		fi


		# /dev/tty for redirection
		read -p "$(tput setaf 2)${question} $(tput sgr0)(${prompt})" yn </dev/tty

		# Default?
		if [ -z "$yn" ]; then
			yn=$default
		fi

		case $yn in
			[Yy]* ) return 0 ;;
			[Nn]* ) return 1 ;;
			* )		echo "Please answer (y)es or (n)o.";;
		esac

	done
}




# Get multi-line string of all sections
# headers without '[' and ']'
_ini_get_all_sections() {
	_ini_dir="${1}"
	_ini_file="${2}"

	# Remove comments
	_lines="$( cat "${_ini_dir}/${_ini_file}" | grep -vE '^[[:space:]]*;' | grep -vE '^[[:space:]]*#' )"

	# Get only lines with sectiions
	_sections="$( echo "${_lines}" | grep -oE '^[[:space:]]*\[[-_A-Za-z0-9]*\]' )"

	# Get section names
	_sections="$( echo "${_sections}" | sed 's/\[//g' | sed 's/\]//g' )"

	echo "${_sections}"
}

# Get value of a section by a key
_ini_get_section_value() {
	_ini_dir="${1}"
	_ini_file="${2}"
	_ini_section="${3}"
	_ini_key="${4}"

	# Remove comments
	_lines="$( cat "${_ini_dir}/${_ini_file}" | grep -vE '^[[:space:]]*;' | grep -vE '^[[:space:]]*#' )"

	# Get section up to (including) key
	_section="$( echo "${_lines}" | awk "/^[[:space:]]*\[${_ini_section}\]/,/^[[:space:]]*${_ini_key}/ { print }" )"

	# Get line with key and extract value
	_block="$( echo "${_section}" | grep -oE "^[[:space:]]*${_ini_key}[[:space:]]*=.*" )"

	# Get value
	_value="$( echo "${_block}" | awk -F  '=' '{ print $2}' )"

	# Remove leading soace
	_value="$( echo "${_value}" | sed 's/^[[:space:]]*//g' )"

	echo "${_value}"
}


_pause() {
	read -rsp $'Press any key to continue...\n' -n1 key
}

_show_header() {

	tput clear

	echo "------------------------------------------------------------"
	echo "-                  Redmine like a boss                     -"
	echo "------------------------------------------------------------"
}


main_menu() {

	while true; do

		_show_header

		echo
		echo "What do you want to do?"
		echo
#		echo "   1. Update sources (Do this first)"
#		echo
		echo "   2. List/check plugins"
		echo "   3. Enable plugin"
		echo "   4. Disable plugin"
		echo
#		echo "   5. List themes"
#		echo "   6. Enable theme"
#		echo "   7. Disable theme"
#		echo
#		echo "   8. Help"
		echo "   9. Exit program"
		echo

		read -p "$(tput setaf 2)Enter a number between 1-9: $(tput sgr0)" number </dev/tty

		case $number in
#			1) return 1 ;;
			2) return 2 ;;
			3) return 3 ;;
			4) return 4 ;;
#			5) return 5 ;;
#			6) return 6 ;;
#			7) return 7 ;;
#			8) return 8 ;;
			9) return 9 ;;
			*) ;;
		esac

	done
}

list_plugins() {

	plugins="$( _ini_get_all_sections "${DIR_REDMINE_PLUGINS}" "plugin.config" )"
	count="$( echo "${plugins}" | grep -c '' )"

	_show_header
	echo
	echo "Available plugins (${count})"
	echo

	i=1
	for section in ${plugins}; do

		_cnt="$(printf "%2d" "${i}")"

		name="$( _ini_get_section_value "${DIR_REDMINE_PLUGINS}" "plugin.config" "${section}" "name" )"
		path="$( _ini_get_section_value "${DIR_REDMINE_PLUGINS}" "plugin.config" "${section}" "path" )"
		version="$( _ini_get_section_value "${DIR_REDMINE_PLUGINS}" "plugin.config" "${section}" "version" )"

		# Check if plugin exists and has a valid path
		_err=""
		if [ "${path}" = "" ]; then
			_err=" $(tput setaf 1)(Broken: No path specified in plugin.config)$(tput sgr0)"
		elif [ ! -d "${DIR_REDMINE_PLUGINS}/${path}" ]; then
			_err=" $(tput setaf 1)(Broken: Invalid path: redmine-plugins/${path})$(tput sgr0)"
		fi

		# Check if plugin is symlinked (enabled)
		_enabled=""
		if [ -L "${DIR_REDMINE}/plugins/${section}" ]; then
			# Check symlink
			real_path="$( realpath "${DIR_REDMINE}/plugins/${section}" )"
			plug_path="${DIR_REDMINE_PLUGINS}/${path}"

			if [ "${real_path}" = "${plug_path}" ]; then
				_enabled=" $(tput setaf 2)(Enabled)$(tput sgr0)"
			else
				_err=" $(tput setaf 1)(Enabled but broken: Invalid symlink for redmine/plugins/${section})$(tput sgr0)"
			fi
		fi

		echo "${_cnt} ${name} (${section} ${version})${_err}${_enabled}"

		i="$((i + 1))"
	done

	echo
	_pause
}


enable_plugin() {

	while true; do

		plugins="$( _ini_get_all_sections "${DIR_REDMINE_PLUGINS}" "plugin.config" )"

		_show_header
		echo
		echo "Plugins that can be enabled"
		echo

		i=1
		valid_numbers=""
		valid_sections=""
		for section in ${plugins}; do

			name="$( _ini_get_section_value "${DIR_REDMINE_PLUGINS}" "plugin.config" "${section}" "name" )"
			path="$( _ini_get_section_value "${DIR_REDMINE_PLUGINS}" "plugin.config" "${section}" "path" )"
			version="$( _ini_get_section_value "${DIR_REDMINE_PLUGINS}" "plugin.config" "${section}" "version" )"

			# Check if plugin exists and has a valid path
			_err="0"
			if [ "${path}" = "" ]; then
				_err="1"
			elif [ ! -d "${DIR_REDMINE_PLUGINS}/${path}" ]; then
				_err="2"
			fi

			# Check if plugin is symlinked (enabled)
			# Symlink could be broken, but still there
			# in that case we cannot enable a plugin with the same name
			_enabled="0"
			if [ -L "${DIR_REDMINE}/plugins/${section}" ]; then
				_enabled="1"
			fi

			# If there is no error and not enabled already
			if [ "${_err}" = "0" ] && [ "${_enabled}" = "0" ]; then

				_cnt="$(printf "%2d" "${i}")"
				echo "${_cnt} ${name} (${version})"

				valid_numbers="$( printf "%s\n%s\n" "${valid_numbers}" "${i}"  )"
				valid_sections="$( printf "%s\n%s\n" "${valid_sections}" "${i}: ${section}"  )"
				i="$((i + 1))"
			fi
		done

		echo


		read -p "$(tput setaf 2)Enter the number of plugin to enable or 'q' to abort: $(tput sgr0)" number </dev/tty

		# Abort
		if [ "${number}" = "q" ]; then
			return 0
		fi

		if [ "${number}" != "" ]; then
			if echo "${valid_numbers}" | grep -oE "^${number}$" >/dev/null 2>&1; then

				_section="$( echo "${valid_sections}" | grep -oE "^${number}:[[:space:]]*.*" | sed "s/${number}:[[:space:]]*//" )"
				_name="$( _ini_get_section_value "${DIR_REDMINE_PLUGINS}" "plugin.config" "${_section}" "name" )"
				_build="$( _ini_get_section_value "${DIR_REDMINE_PLUGINS}" "plugin.config" "${_section}" "build" )"
				_install="$( _ini_get_section_value "${DIR_REDMINE_PLUGINS}" "plugin.config" "${_section}" "install" )"



				if _ask "Symlink \"${_name}\" (${_section}) to Redmin plugin directory?" "Y"; then

					### 01 Symlink
					cd "${DIR_BASE}"
					ln -s "../../redmine-plugins/${_section}" "redmine/plugins/${_section}"

					### 02 Update Bundles
					if _ask "Update Redmine bundles?" "Y"; then
						cd "${DIR_REDMINE}"
						bundle update
					fi

					### 03 Install Bundles
					if _ask "Install potentiel new Redmine bundles?" "Y"; then
						cd "${DIR_REDMINE}"
						bundle install --without development test
					fi

					### 04 Build Plugin
					if [ "${_build}" != "" ]; then
						echo "\"${_name}\" requires to be build first with the following command:"
						echo  "  \$ ${_build}"
						if _ask "Execute build?" "Y"; then
							cd "${DIR_REDMINE_PLUGINS}/${_section}/"
							eval "${_build}"
						fi
					else
						echo "\"${_name}\" does not require builds."
					fi

					### 05 Database migrations
					if [ "${_install}" != "" ]; then
						echo "\"${_name}\" requires the following database migrations:"
						echo  "  \$ ${_install}"
						if _ask "Run database migrations?" "Y"; then
							cd "${DIR_REDMINE}"
							eval "${_install}"
						fi
					else
						echo "\"${_name}\" does not require database migrations."
					fi

					echo
					echo "\"${_name}\" installed. Restart Redmine"
					echo

				fi
				_pause
			fi
		fi

	done

	echo
	_pause
}






disable_plugin() {

	while true; do

		plugins="$( _ini_get_all_sections "${DIR_REDMINE_PLUGINS}" "plugin.config" )"

		_show_header
		echo
		echo "Uninstall plugins"
		echo

		i=1
		valid_numbers=""
		valid_sections=""


		cd "${DIR_REDMINE}/plugins"
		symlinks="$( find . -type l )"


		for symlink in ${symlinks}; do

			# Remove leading './' to get the section name
			section="$( echo "${symlink}" | sed 's|\./||g' )"

			name="$( _ini_get_section_value "${DIR_REDMINE_PLUGINS}" "plugin.config" "${section}" "name" )"
			path="$( _ini_get_section_value "${DIR_REDMINE_PLUGINS}" "plugin.config" "${section}" "path" )"
			version="$( _ini_get_section_value "${DIR_REDMINE_PLUGINS}" "plugin.config" "${section}" "version" )"

			# Check if plugin exists and has a valid path
			_err="0"
			if [ "${path}" = "" ]; then
				_err="1"
			elif [ ! -d "${DIR_REDMINE_PLUGINS}/${path}" ]; then
				_err="2"
			fi

			# Check if plugin is symlinked (enabled)
			_enabled="0"
			if [ -L "${DIR_REDMINE}/plugins/${section}" ]; then
				# Check symlink
				real_path="$( realpath "${DIR_REDMINE}/plugins/${section}" )"
				plug_path="${DIR_REDMINE_PLUGINS}/${path}"

				if [ "${real_path}" = "${plug_path}" ]; then
					_enabled="1"
				else
					_err="3"
				fi
			fi

			# If there is no error and not enabled already
			if [ "${_err}" = "0" ] && [ "${_enabled}" = "1" ]; then

				_cnt="$(printf "%2d" "${i}")"
				echo "${_cnt} ${name} (${version})"

				valid_numbers="$( printf "%s\n%s\n" "${valid_numbers}" "${i}"  )"
				valid_sections="$( printf "%s\n%s\n" "${valid_sections}" "${i}: ${section}"  )"
				i="$((i + 1))"
			fi
		done

		echo


		read -p "$(tput setaf 2)Enter the number of plugin to enable or 'q' to abort: $(tput sgr0)" number </dev/tty

		# Abort
		if [ "${number}" = "q" ]; then
			return 0
		fi

		if [ "${number}" != "" ]; then
			if echo "${valid_numbers}" | grep -oE "^${number}$" >/dev/null 2>&1; then

				_section="$( echo "${valid_sections}" | grep -oE "^${number}:[[:space:]]*.*" | sed "s/${number}:[[:space:]]*//" )"
				_name="$( _ini_get_section_value "${DIR_REDMINE_PLUGINS}" "plugin.config" "${_section}" "name" )"
				_remove="$( _ini_get_section_value "${DIR_REDMINE_PLUGINS}" "plugin.config" "${_section}" "remove" )"


				if _ask "Uninstall \"${_name}\" (${_section}) ?" "Y"; then

					### 01 Downgrade Plugin
					if [ "${_remove}" != "" ]; then
						echo "\"${_name}\" requires a database downgrade with the following command:"
						echo  "  \$ ${_remove}"
						if _ask "Execute downgrade?" "Y"; then
							cd "${DIR_REDMINE}"
							eval "${_remove}"

							if _ask "Remove symlink?" "Y"; then
								rm "${DIR_REDMINE}/plugins/${_section}"
								echo
								echo "\"${_name}\" uninstalled. Restart Redmine"
								echo
							else
								echo "$(tput setaf 1)Aborted$(tput sgr0)"
							fi
						else
							echo "$(tput setaf 1)Aborted$(tput sgr0)"
						fi
					else
						echo "\"${_name}\" does not require a database downgrade."
						if _ask "Remove symlink?" "Y"; then
							rm "${DIR_REDMINE}/plugins/${_section}"
							echo
							echo "\"${_name}\" uninstalled. Restart Redmine"
							echo
						else
							echo "$(tput setaf 1)Aborted$(tput sgr0)"
						fi
					fi
				else
					echo "$(tput setaf 1)Aborted$(tput sgr0)"
				fi
				_pause
			fi
		fi

	done

	echo
	_pause
}





while true; do

	main_menu
	choice="$?"

	case $choice in
#		1) echo "1" ;;
		2) list_plugins ;;
		3) enable_plugin ;;
		4) disable_plugin ;;
#		5) echo "5" ;;
#		6) echo "6" ;;
#		7) echo "7" ;;
#		8) echo "8" ;;
		9) exit 0 ;;
		*) exit 1 ;;
	esac
done

exit 0