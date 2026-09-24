#!/bin/bash

__gsp_cursor_index_in_current_word() {
    local remaining="${COMP_LINE}"

    local word
    for word in "${COMP_WORDS[@]::COMP_CWORD}"; do
        remaining="${remaining##*([[:space:]])"${word}"*([[:space:]])}"
    done

    local -ir index="$((COMP_POINT - ${#COMP_LINE} + ${#remaining}))"
    if [[ "${index}" -le 0 ]]; then
        printf 0
    else
        printf %s "${index}"
    fi
}

# positional arguments:
#
# - 1: the current (sub)command's count of positional arguments
#
# required variables:
#
# - repeating_flags: the repeating flags that the current (sub)command can accept
# - non_repeating_flags: the non-repeating flags that the current (sub)command can accept
# - repeating_options: the repeating options that the current (sub)command can accept
# - non_repeating_options: the non-repeating options that the current (sub)command can accept
# - positional_number: value ignored
# - unparsed_words: unparsed words from the current command line
#
# modified variables:
#
# - non_repeating_flags: remove flags for this (sub)command that are already on the command line
# - non_repeating_options: remove options for this (sub)command that are already on the command line
# - positional_number: set to the current positional number
# - unparsed_words: remove all flags, options, and option values for this (sub)command
__gsp_offer_flags_options() {
    local -ir positional_count="${1}"
    positional_number=0

    local was_flag_option_terminator_seen=false
    local is_parsing_option_value=false

    local -ar unparsed_word_indices=("${!unparsed_words[@]}")
    local -i word_index
    for word_index in "${unparsed_word_indices[@]}"; do
        if "${is_parsing_option_value}"; then
            # This word is an option value:
            # Reset marker for next word iff not currently the last word
            [[ "${word_index}" -ne "${unparsed_word_indices[${#unparsed_word_indices[@]} - 1]}" ]] && is_parsing_option_value=false
            unset "unparsed_words[${word_index}]"
            # Do not process this word as a flag or an option
            continue
        fi

        local word="${unparsed_words["${word_index}"]}"
        if ! "${was_flag_option_terminator_seen}"; then
            case "${word}" in
            --)
                unset "unparsed_words[${word_index}]"
                # by itself -- is a flag/option terminator, but if it is the last word, it is the start of a completion
                if [[ "${word_index}" -ne "${unparsed_word_indices[${#unparsed_word_indices[@]} - 1]}" ]]; then
                    was_flag_option_terminator_seen=true
                fi
                continue
                ;;
            -*)
                # ${word} is a flag or an option
                # If ${word} is an option, mark that the next word to be parsed is an option value
                local option
                for option in "${repeating_options[@]}" "${non_repeating_options[@]}"; do
                    [[ "${word}" = "${option}" ]] && is_parsing_option_value=true && break
                done

                # Remove ${word} from ${non_repeating_flags} or ${non_repeating_options} so it isn't offered again
                local not_found=true
                local -i index
                for index in "${!non_repeating_flags[@]}"; do
                    if [[ "${non_repeating_flags[${index}]}" = "${word}" ]]; then
                        unset "non_repeating_flags[${index}]"
                        non_repeating_flags=("${non_repeating_flags[@]}")
                        not_found=false
                        break
                    fi
                done
                if "${not_found}"; then
                    for index in "${!non_repeating_flags[@]}"; do
                        if [[ "${non_repeating_flags[${index}]}" = "${word}" ]]; then
                            unset "non_repeating_flags[${index}]"
                            non_repeating_flags=("${non_repeating_flags[@]}")
                            break
                        fi
                    done
                fi
                unset "unparsed_words[${word_index}]"
                continue
                ;;
            esac
        fi

        # ${word} is neither a flag, nor an option, nor an option value
        if [[ "${positional_number}" -lt "${positional_count}" || "${positional_count}" -lt 0 ]]; then
            # ${word} is a positional
            ((positional_number++))
            unset "unparsed_words[${word_index}]"
        else
            if [[ -z "${word}" ]]; then
                # Could be completing a flag, option, or subcommand
                positional_number=-1
            else
                # ${word} is a subcommand or invalid, so stop processing this (sub)command
                positional_number=-2
            fi
            break
        fi
    done

    unparsed_words=("${unparsed_words[@]}")

    if\
        ! "${was_flag_option_terminator_seen}"\
        && ! "${is_parsing_option_value}"\
        && [[ ("${cur}" = -* && "${positional_number}" -ge 0) || "${positional_number}" -eq -1 ]]
    then
        COMPREPLY+=($(compgen -W "${repeating_flags[*]} ${non_repeating_flags[*]} ${repeating_options[*]} ${non_repeating_options[*]}" -- "${cur}"))
    fi
}

__gsp_add_completions() {
    local completion
    while IFS='' read -r completion; do
        COMPREPLY+=("${completion}")
    done < <(IFS=$'\n' compgen "${@}" -- "${cur}")
}

__gsp_custom_complete() {
    if [[ -n "${cur}" || -z ${COMP_WORDS[${COMP_CWORD}]} || "${COMP_LINE:${COMP_POINT}:1}" != ' ' ]]; then
        local -ar words=("${COMP_WORDS[@]}")
    else
        local -ar words=("${COMP_WORDS[@]::${COMP_CWORD}}" '' "${COMP_WORDS[@]:${COMP_CWORD}}")
    fi

    "${COMP_WORDS[0]}" "${@}" "${words[@]}"
}

_gsp() {
    local state
    state="$(shopt -p;shopt -po)"
    trap "${state//$'\n'/;}" RETURN
    shopt -s extglob
    set +o history +o posix

    local -xr SAP_SHELL=bash
    local -x SAP_SHELL_VERSION
    SAP_SHELL_VERSION="$(IFS='.';printf %s "${BASH_VERSINFO[*]}")"
    local -r SAP_SHELL_VERSION

    local -r cur="${2}"
    local -r prev="${3}"

    local -i positional_number
    local -a unparsed_words=("${COMP_WORDS[@]:1:${COMP_CWORD}}")

    local -a repeating_flags=()
    local -a non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    local -a repeating_options=()
    local -a non_repeating_options=(--profile --timeout-seconds --session-store)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    esac

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    auth|org|member|repo|space|traffic|quota|invite|access|audit|issue|pr|completion|help)
        # Offer subcommand argument completions
        "_gsp_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'auth org member repo space traffic quota invite access audit issue pr completion help' -- "${cur}"))
        ;;
    esac
}

_gsp_auth() {
    repeating_flags=()
    non_repeating_flags=(--version -h --help)
    repeating_options=()
    non_repeating_options=()
    __gsp_offer_flags_options 0

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    login|status|logout|use|spaces-alpha-smoke|spaces-access-smoke|permission-set-probe)
        # Offer subcommand argument completions
        "_gsp_auth_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'login status logout use spaces-alpha-smoke spaces-access-smoke permission-set-probe' -- "${cur}"))
        ;;
    esac
}

_gsp_auth_login() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --no-browser --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --pds --callback-port --permission-set)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--pds')
        return
        ;;
    '--callback-port')
        return
        ;;
    '--permission-set')
        return
        ;;
    esac
}

_gsp_auth_status() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    esac
}

_gsp_auth_logout() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    esac
}

_gsp_auth_use() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    esac
}

_gsp_auth_spaces-alpha-smoke() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --pds --did-document-origin --contract)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--pds')
        return
        ;;
    '--did-document-origin')
        return
        ;;
    '--contract')
        return
        ;;
    esac
}

_gsp_auth_spaces-access-smoke() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --yes --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --member-profile)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--member-profile')
        return
        ;;
    esac
}

_gsp_auth_permission-set-probe() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --pds --permission-set)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--pds')
        return
        ;;
    '--permission-set')
        return
        ;;
    esac
}

_gsp_org() {
    repeating_flags=()
    non_repeating_flags=(--version -h --help)
    repeating_options=()
    non_repeating_options=()
    __gsp_offer_flags_options 0

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    create|get|list)
        # Offer subcommand argument completions
        "_gsp_org_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'create get list' -- "${cur}"))
        ;;
    esac
}

_gsp_org_create() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --idempotency-key --name)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--idempotency-key')
        return
        ;;
    '--name')
        return
        ;;
    esac
}

_gsp_org_get() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --organization --organization-id)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--organization')
        return
        ;;
    '--organization-id')
        return
        ;;
    esac
}

_gsp_org_list() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --cursor --limit)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--cursor')
        return
        ;;
    '--limit')
        return
        ;;
    esac
}

_gsp_member() {
    repeating_flags=()
    non_repeating_flags=(--version -h --help)
    repeating_options=()
    non_repeating_options=()
    __gsp_offer_flags_options 0

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    add|list|update|remove)
        # Offer subcommand argument completions
        "_gsp_member_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'add list update remove' -- "${cur}"))
        ;;
    esac
}

_gsp_member_add() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --organization --organization-id -R --repo --repository-id --idempotency-key --principal --role)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--organization')
        return
        ;;
    '--organization-id')
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '--repository-id')
        return
        ;;
    '--idempotency-key')
        return
        ;;
    '--principal')
        return
        ;;
    '--role')
        return
        ;;
    esac
}

_gsp_member_list() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --organization --organization-id -R --repo --repository-id --cursor --limit)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--organization')
        return
        ;;
    '--organization-id')
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '--repository-id')
        return
        ;;
    '--cursor')
        return
        ;;
    '--limit')
        return
        ;;
    esac
}

_gsp_member_update() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --organization --organization-id -R --repo --repository-id --idempotency-key --principal --role)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--organization')
        return
        ;;
    '--organization-id')
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '--repository-id')
        return
        ;;
    '--idempotency-key')
        return
        ;;
    '--principal')
        return
        ;;
    '--role')
        return
        ;;
    esac
}

_gsp_member_remove() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --organization --organization-id -R --repo --repository-id --idempotency-key --principal)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--organization')
        return
        ;;
    '--organization-id')
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '--repository-id')
        return
        ;;
    '--idempotency-key')
        return
        ;;
    '--principal')
        return
        ;;
    esac
}

_gsp_repo() {
    repeating_flags=()
    non_repeating_flags=(--version -h --help)
    repeating_options=()
    non_repeating_options=()
    __gsp_offer_flags_options 0

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    create|view|list|search|deactivate|clone|remote|tree|blob|diff|repair-space-policy)
        # Offer subcommand argument completions
        "_gsp_repo_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'create view list search deactivate clone remote tree blob diff repair-space-policy' -- "${cur}"))
        ;;
    esac
}

_gsp_repo_create() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --public --internal --private --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --idempotency-key)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--idempotency-key')
        return
        ;;
    esac
}

_gsp_repo_view() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    esac
}

_gsp_repo_list() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --cursor --limit)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--cursor')
        return
        ;;
    '--limit')
        return
        ;;
    esac
}

_gsp_repo_search() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --cursor --limit)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--cursor')
        return
        ;;
    '--limit')
        return
        ;;
    esac
}

_gsp_repo_deactivate() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --idempotency-key)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--idempotency-key')
        return
        ;;
    esac
}

_gsp_repo_clone() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store)
    __gsp_offer_flags_options 2

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    esac
}

_gsp_repo_remote() {
    repeating_flags=()
    non_repeating_flags=(--version -h --help)
    repeating_options=()
    non_repeating_options=()
    __gsp_offer_flags_options 0

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    set)
        # Offer subcommand argument completions
        "_gsp_repo_remote_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'set' -- "${cur}"))
        ;;
    esac
}

_gsp_repo_remote_set() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --force --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --remote)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--remote')
        return
        ;;
    esac
}

_gsp_repo_tree() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --ref --path)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--ref')
        return
        ;;
    '--path')
        return
        ;;
    esac
}

_gsp_repo_blob() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --ref)
    __gsp_offer_flags_options 2

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--ref')
        return
        ;;
    esac
}

_gsp_repo_diff() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --no-pager --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --repository --color)
    __gsp_offer_flags_options 2

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--repository')
        return
        ;;
    '--color')
        return
        ;;
    esac
}

_gsp_repo_repair-space-policy() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    esac
}

_gsp_space() {
    repeating_flags=()
    non_repeating_flags=(--version -h --help)
    repeating_options=()
    non_repeating_options=()
    __gsp_offer_flags_options 0

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    member|delete)
        # Offer subcommand argument completions
        "_gsp_space_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'member delete' -- "${cur}"))
        ;;
    esac
}

_gsp_space_member() {
    repeating_flags=()
    non_repeating_flags=(--version -h --help)
    repeating_options=()
    non_repeating_options=()
    __gsp_offer_flags_options 0

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    put|add|list)
        # Offer subcommand argument completions
        "_gsp_space_member_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'put add list' -- "${cur}"))
        ;;
    esac
}

_gsp_space_member_put() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --yes --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --space --did --read --write)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--space')
        return
        ;;
    '--did')
        return
        ;;
    '--read')
        return
        ;;
    '--write')
        return
        ;;
    esac
}

_gsp_space_member_add() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --yes --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --space --did)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--space')
        return
        ;;
    '--did')
        return
        ;;
    esac
}

_gsp_space_member_list() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --space --cursor --limit)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--space')
        return
        ;;
    '--cursor')
        return
        ;;
    '--limit')
        return
        ;;
    esac
}

_gsp_space_delete() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --yes --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --space --verification-space)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--space')
        return
        ;;
    '--verification-space')
        return
        ;;
    esac
}

_gsp_traffic() {
    repeating_flags=()
    non_repeating_flags=(--version -h --help)
    repeating_options=()
    non_repeating_options=()
    __gsp_offer_flags_options 0

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    status|pause|resume)
        # Offer subcommand argument completions
        "_gsp_traffic_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'status pause resume' -- "${cur}"))
        ;;
    esac
}

_gsp_traffic_status() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    esac
}

_gsp_traffic_pause() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=(--target)
    non_repeating_options=(--profile --timeout-seconds --session-store --idempotency-key)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--idempotency-key')
        return
        ;;
    '--target')
        return
        ;;
    esac
}

_gsp_traffic_resume() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=(--target)
    non_repeating_options=(--profile --timeout-seconds --session-store --idempotency-key)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--idempotency-key')
        return
        ;;
    '--target')
        return
        ;;
    esac
}

_gsp_quota() {
    repeating_flags=()
    non_repeating_flags=(--version -h --help)
    repeating_options=()
    non_repeating_options=()
    __gsp_offer_flags_options 0

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    usage|show|list|set|reset|reconcile)
        # Offer subcommand argument completions
        "_gsp_quota_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'usage show list set reset reconcile' -- "${cur}"))
        ;;
    esac
}

_gsp_quota_usage() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --scope --subject)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--scope')
        return
        ;;
    '--subject')
        return
        ;;
    esac
}

_gsp_quota_show() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --scope --subject)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--scope')
        return
        ;;
    '--subject')
        return
        ;;
    esac
}

_gsp_quota_list() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --cursor --limit)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--cursor')
        return
        ;;
    '--limit')
        return
        ;;
    esac
}

_gsp_quota_set() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --scope --subject --idempotency-key --repository-limit --byte-limit --push-limit)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--scope')
        return
        ;;
    '--subject')
        return
        ;;
    '--idempotency-key')
        return
        ;;
    '--repository-limit')
        return
        ;;
    '--byte-limit')
        return
        ;;
    '--push-limit')
        return
        ;;
    esac
}

_gsp_quota_reset() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --scope --subject --idempotency-key)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--scope')
        return
        ;;
    '--subject')
        return
        ;;
    '--idempotency-key')
        return
        ;;
    esac
}

_gsp_quota_reconcile() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --scope --subject --idempotency-key)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--scope')
        return
        ;;
    '--subject')
        return
        ;;
    '--idempotency-key')
        return
        ;;
    esac
}

_gsp_invite() {
    repeating_flags=()
    non_repeating_flags=(--version -h --help)
    repeating_options=()
    non_repeating_options=()
    __gsp_offer_flags_options 0

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    create|list|revoke|redeem)
        # Offer subcommand argument completions
        "_gsp_invite_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'create list revoke redeem' -- "${cur}"))
        ;;
    esac
}

_gsp_invite_create() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --idempotency-key --max-uses --expires-in-seconds)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--idempotency-key')
        return
        ;;
    '--max-uses')
        return
        ;;
    '--expires-in-seconds')
        return
        ;;
    esac
}

_gsp_invite_list() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --cursor --limit)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--cursor')
        return
        ;;
    '--limit')
        return
        ;;
    esac
}

_gsp_invite_revoke() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --idempotency-key)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--idempotency-key')
        return
        ;;
    esac
}

_gsp_invite_redeem() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --idempotency-key --code-file)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--idempotency-key')
        return
        ;;
    '--code-file')
        return
        ;;
    esac
}

_gsp_access() {
    repeating_flags=()
    non_repeating_flags=(--version -h --help)
    repeating_options=()
    non_repeating_options=()
    __gsp_offer_flags_options 0

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    explain|status|list|grant|suspend|resume)
        # Offer subcommand argument completions
        "_gsp_access_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'explain status list grant suspend resume' -- "${cur}"))
        ;;
    esac
}

_gsp_access_explain() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --kind --organization --organization-id --project --project-id --repository-id --space-id --ref --collection --record-uri --principal --action)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--kind')
        __gsp_add_completions -W 'organization'$'\n''project'$'\n''repository'$'\n''space'$'\n''record'
        return
        ;;
    '--organization')
        return
        ;;
    '--organization-id')
        return
        ;;
    '--project')
        return
        ;;
    '--project-id')
        return
        ;;
    '--repository-id')
        return
        ;;
    '--space-id')
        return
        ;;
    '--ref')
        return
        ;;
    '--collection')
        return
        ;;
    '--record-uri')
        return
        ;;
    '--principal')
        return
        ;;
    '--action')
        return
        ;;
    esac
}

_gsp_access_status() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    esac
}

_gsp_access_list() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --cursor --limit)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--cursor')
        return
        ;;
    '--limit')
        return
        ;;
    esac
}

_gsp_access_grant() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --idempotency-key)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--idempotency-key')
        return
        ;;
    esac
}

_gsp_access_suspend() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --idempotency-key)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--idempotency-key')
        return
        ;;
    esac
}

_gsp_access_resume() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --idempotency-key)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--idempotency-key')
        return
        ;;
    esac
}

_gsp_audit() {
    repeating_flags=()
    non_repeating_flags=(--version -h --help)
    repeating_options=()
    non_repeating_options=()
    __gsp_offer_flags_options 0

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    list)
        # Offer subcommand argument completions
        "_gsp_audit_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'list' -- "${cur}"))
        ;;
    esac
}

_gsp_audit_list() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store --cursor --limit)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '--cursor')
        return
        ;;
    '--limit')
        return
        ;;
    esac
}

_gsp_issue() {
    repeating_flags=()
    non_repeating_flags=(--version -h --help)
    repeating_options=()
    non_repeating_options=()
    __gsp_offer_flags_options 0

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    create|list|view|edit|close|reopen|adopt-baseline|resume-mutation)
        # Offer subcommand argument completions
        "_gsp_issue_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'create list view edit close reopen adopt-baseline resume-mutation' -- "${cur}"))
        ;;
    esac
}

_gsp_issue_create() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run -e --editor --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo --idempotency-key -t --title -b --body -F --body-file --parent)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '--idempotency-key')
        return
        ;;
    '-t'|'--title')
        return
        ;;
    '-b'|'--body')
        return
        ;;
    '-F'|'--body-file')
        return
        ;;
    '--parent')
        return
        ;;
    esac
}

_gsp_issue_list() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --has-children --blocked --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo --cursor --limit --skip --max-count --state --parent --related --blocking --blocked-by)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '--cursor')
        return
        ;;
    '--limit')
        return
        ;;
    '--skip')
        return
        ;;
    '--max-count')
        return
        ;;
    '--state')
        __gsp_add_completions -W 'open'$'\n''closed'$'\n''all'
        return
        ;;
    '--parent')
        return
        ;;
    '--related')
        return
        ;;
    '--blocking')
        return
        ;;
    '--blocked-by')
        return
        ;;
    esac
}

_gsp_issue_view() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    esac
}

_gsp_issue_edit() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --editor --remove-parent --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo --title -b --body -F --body-file --parent --add-sub-issue --remove-sub-issue --add-related --remove-related --add-blocking --remove-blocking --add-blocked-by --remove-blocked-by --idempotency-key)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '--title')
        return
        ;;
    '-b'|'--body')
        return
        ;;
    '-F'|'--body-file')
        return
        ;;
    '--parent')
        return
        ;;
    '--add-sub-issue')
        return
        ;;
    '--remove-sub-issue')
        return
        ;;
    '--add-related')
        return
        ;;
    '--remove-related')
        return
        ;;
    '--add-blocking')
        return
        ;;
    '--remove-blocking')
        return
        ;;
    '--add-blocked-by')
        return
        ;;
    '--remove-blocked-by')
        return
        ;;
    '--idempotency-key')
        return
        ;;
    esac
}

_gsp_issue_close() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo --idempotency-key)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '--idempotency-key')
        return
        ;;
    esac
}

_gsp_issue_reopen() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo --idempotency-key)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '--idempotency-key')
        return
        ;;
    esac
}

_gsp_issue_adopt-baseline() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo --source-digest)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '--source-digest')
        return
        ;;
    esac
}

_gsp_issue_resume-mutation() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    esac
}

_gsp_pr() {
    repeating_flags=()
    non_repeating_flags=(--version -h --help)
    repeating_options=()
    non_repeating_options=()
    __gsp_offer_flags_options 0

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    create|list|view|edit|diff|comment|comments|review|status|merge)
        # Offer subcommand argument completions
        "_gsp_pr_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'create list view edit diff comment comments review status merge' -- "${cur}"))
        ;;
    esac
}

_gsp_pr_create() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo -t --title -b --body -F --body-file --base --head --idempotency-key)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '-t'|'--title')
        return
        ;;
    '-b'|'--body')
        return
        ;;
    '-F'|'--body-file')
        return
        ;;
    '--base')
        return
        ;;
    '--head')
        return
        ;;
    '--idempotency-key')
        return
        ;;
    esac
}

_gsp_pr_list() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo --state --author --cursor --limit)
    __gsp_offer_flags_options 0

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '--state')
        return
        ;;
    '--author')
        return
        ;;
    '--cursor')
        return
        ;;
    '--limit')
        return
        ;;
    esac
}

_gsp_pr_view() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --no-pager --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    esac
}

_gsp_pr_edit() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --editor --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo --title -b --body -F --body-file --idempotency-key)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '--title')
        return
        ;;
    '-b'|'--body')
        return
        ;;
    '-F'|'--body-file')
        return
        ;;
    '--idempotency-key')
        return
        ;;
    esac
}

_gsp_pr_diff() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --no-pager --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo --round --color)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '--round')
        return
        ;;
    '--color')
        return
        ;;
    esac
}

_gsp_pr_comment() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --blocking --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo -b --body -F --body-file --round --path --side --start-line --line --severity --category --idempotency-key)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '-b'|'--body')
        return
        ;;
    '-F'|'--body-file')
        return
        ;;
    '--round')
        return
        ;;
    '--path')
        return
        ;;
    '--side')
        return
        ;;
    '--start-line')
        return
        ;;
    '--line')
        return
        ;;
    '--severity')
        return
        ;;
    '--category')
        return
        ;;
    '--idempotency-key')
        return
        ;;
    esac
}

_gsp_pr_comments() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo --round --cursor --limit)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '--round')
        return
        ;;
    '--cursor')
        return
        ;;
    '--limit')
        return
        ;;
    esac
}

_gsp_pr_review() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --comment --approve --request-changes --version -h --help)
    repeating_options=(--unverified)
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo --round -b --body -F --body-file --evidence-file --idempotency-key)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '--round')
        return
        ;;
    '-b'|'--body')
        return
        ;;
    '-F'|'--body-file')
        return
        ;;
    '--evidence-file')
        return
        ;;
    '--unverified')
        return
        ;;
    '--idempotency-key')
        return
        ;;
    esac
}

_gsp_pr_status() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    esac
}

_gsp_pr_merge() {
    repeating_flags=()
    non_repeating_flags=(--json --verbose --non-interactive --dry-run --version -h --help)
    repeating_options=()
    non_repeating_options=(--profile --timeout-seconds --session-store -R --repo --match-head-commit --idempotency-key)
    __gsp_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--profile')
        return
        ;;
    '--timeout-seconds')
        return
        ;;
    '--session-store')
        __gsp_add_completions -W 'keychain'$'\n''file'
        return
        ;;
    '-R'|'--repo')
        return
        ;;
    '--match-head-commit')
        return
        ;;
    '--idempotency-key')
        return
        ;;
    esac
}

_gsp_completion() {
    repeating_flags=()
    non_repeating_flags=(--version -h --help)
    repeating_options=()
    non_repeating_options=()
    __gsp_offer_flags_options 1

    # Offer positional completions
    case "${positional_number}" in
    1)
        __gsp_add_completions -W 'bash'$'\n''zsh'$'\n''fish'
        return
        ;;
    esac
}

_gsp_help() {
    repeating_flags=()
    non_repeating_flags=(--version)
    repeating_options=()
    non_repeating_options=()
    __gsp_offer_flags_options -1
}

complete -o filenames -F _gsp gsp