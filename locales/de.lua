--[[ 🐉 rde_aidoctor v1.0.0 — Deutsch Locale ]]
return {
    -- ─── TOD HUD ───────────────────────────────────────────────────
    death_ui_header     = '🚨 KRITISCHER ZUSTAND',
    death_ui_bleeding   = '🩸 Blutverlust: %d%%',
    death_ui_time       = '⏱ Zeit am Boden: %s',
    death_ui_injury     = '🏥 %s',

    -- ─── VERLETZUNGSARTEN ──────────────────────────────────────────
    bleeding_out        = 'Verbluten',
    cardiac_arrest      = 'Herzstillstand',
    severe_trauma       = 'Schweres Trauma',
    head_injury         = 'Kopftrauma',
    gunshot_wound       = 'Schussverletzung',
    vehicle_crash       = 'Verkehrsunfall',

    -- ─── TOD-MENÜ ──────────────────────────────────────────────────
    menu_title              = '🚨 Notfall-Status',
    menu_vitals             = 'Vitalwerte',
    menu_vitals_desc        = '❤️ %s  |  🩸 %d%%  |  ⏱ %s',
    menu_status_dead        = 'Kritischer Zustand',
    menu_call_ambulance     = '🚑 Krankenwagen rufen',
    menu_call_cost          = 'Notarztgebühr: $%d',
    menu_ambulance_enroute  = '🚑 Krankenwagen Unterwegs',
    menu_ambulance_dist     = 'ETA ~%ds · Entfernung: %dm',
    menu_ambulance_wait     = 'Hilfe ist unterwegs — bleib unten',
    menu_respawn            = '🏥 Im Krankenhaus wiederbeleben',
    menu_respawn_desc       = 'Aufgeben und im nächsten Krankenhaus aufwachen',
    menu_respawn_locked     = '🔒 Wiederbelebung gesperrt — noch %ds',
    menu_respawn_locked_desc= 'Halt durch, vielleicht kommt noch Hilfe',

    -- ─── BENACHRICHTIGUNGEN ────────────────────────────────────────
    revived_success         = 'Du wurdest stabilisiert und wiederbelebt!',
    respawned               = 'Du bist im %s aufgewacht',
    doctor_called           = 'KI-Krankenwagen gerufen!',
    doctor_called_desc      = 'ETA ~%ds · Gebühr: $%d abgebucht',
    doctor_arrived          = 'Sanitäter eingetroffen',
    doctor_treating         = '⚕ Notfallbehandlung läuft...',
    doctor_success          = '✅ Stabilisiert & Wiederbelebt!',
    doctor_failed           = '❌ Sanitäter konnte dich nicht erreichen',
    service_unavailable     = 'Kein Krankenwagen in deiner Nähe verfügbar',
    too_far                 = 'Standort zu abgelegen für Rettungsdienste',
    no_money                = 'Nicht genug Geld — Es fehlen $%d',
    payment_failed          = 'Zahlung fehlgeschlagen',
    admin_revived_by        = 'Du wurdest von einem Administrator wiederbelebt',
    admin_revived_target    = '%s wurde wiederbelebt',
}