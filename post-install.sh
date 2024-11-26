#!/bin/sh

install_ext () {
    local ext="$1"

    if [ ! -d "./ext/$ext" ]; then
        echo "Extension '$ext' not found"
        return 1
    fi

    echo "Installing $ext ..."

    if is_installed "$ext"; then
        echo "  $ext is already installed"
        return 0
    fi

    for req in $(list_required "./ext/$ext/info.xml"); do
        echo "  Requires: $req"
        local req_name="$(cv ext:list -I --columns="name" "/$req/" | head -n 1)"
        install_ext "$req_name" || return 1
    done

    cv ext:enable "$ext"
}

is_installed () {
    local ext="$1"
    test -n "$(cv ext:list -iI --columns="name" "/$ext/")"
}

list_required () {
    local info_file="$1"

    grep -qF "<requires>" "$info_file" || return 0

    grep -nP "</?requires>" "$info_file" \
    | cut -d ":" -f 1 \
    | xargs -L 2 sh -c 'sed -n "$(($0 + 1)),$(($1 - 1))p" '"$info_file" \
    | grep -oP "<ext>\K[^<]+"
}

# Install all extensions in the ext/ directory
for ext_dir in ./ext/*; do
    [ -f "$ext_dir" ] && continue

    install_ext "$(basename "$ext_dir")"
done

# Perform necessary database upgrades
cv upgrade:db

exit 0

# --- GPAT-specific settings ------------------------------------------------- #

# Default currency = EUR
cv api4 Setting.set +v defaultCurrency="EUR"

# Default contact country = Austria (1014)
cv api4 Setting.set +v defaultContactCountry="1014"

# Extension settings: com.cividesk.normalize
cv api4 Setting.set +v contact_FullFirst="1"
cv api4 Setting.set +v contact_OrgCaps="0"
cv api4 Setting.set +v phone_normalize="1"
cv api4 Setting.set +v phone_IntlPrefix="1"
cv api4 Setting.set +v address_CityCaps="0"
cv api4 Setting.set +v address_StreetCaps="0"
cv api4 Setting.set +v address_Zip="1"

# Extension settings: de.systopia.fastactivity
cv api4 Setting.set +v fastactivity_tab_col_campaign_title="1"
cv api4 Setting.set +v fastactivity_tab_col_case="0"
cv api4 Setting.set +v fastactivity_tab_exclude_case_activities="0"
cv api4 Setting.set +v fastactivity_replace_tab="1"
cv api4 Setting.set +v fastactivity_replace_search="1"

# Extension settings: org.project60.sepa
cv api4 SepaCreditor.create \
    +v creditor_id="1" \
    +v currency="EUR" \
    +v iban="AT542011182129643403" \
    +v identifier="AT53ZZZ00000006160" \
    +v label="GP Erste Bank" \
    +v mandate_active="1" \
    +v name="Greenpeace" \
    +v sepa_file_format_id="pain_008_001_02_OTHERID" \
    +v uses_bic="0"

cv api4 Setting.set \
    +v batching_default_creditor="1" \
    +v allow_mandate_modification="0" \
    +v batching_FRST_notice="1" \
    +v batching_OOFF_horizon="7" \
    +v batching_OOFF_notice="1" \
    +v batching_RCUR_grace="10" \
    +v batching_RCUR_horizon="5" \
    +v batching_RCUR_notice="1" \
    +v custom_txmsg="Greenpeace Beitrag Danke" \
    +v cycledays="3,10,17,25" \
    +v exclude_weekends="1" \
    +v pp_buffer_days="2" \
    +v sdd_async_batching="1" \
    +v sdd_no_draft_xml="0" \
    +v sdd_skip_closed="1" \
    +v sepacustom_reference_prefix="GP"

# Import data from Statistik Austria for de.systopia.postcodeat
cv api PostcodeAT.importstatistikaustria
