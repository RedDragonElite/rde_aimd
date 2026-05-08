--[[ 🐉 rde_aidoctor v1.0.0 — English Locale ]]
return {
    -- ─── DEATH HUD ─────────────────────────────────────────────────
    death_ui_header     = '🚨 CRITICAL CONDITION',
    death_ui_bleeding   = '🩸 Blood Loss: %d%%',
    death_ui_time       = '⏱ Time Down: %s',
    death_ui_injury     = '🏥 %s',

    -- ─── INJURY TYPES ──────────────────────────────────────────────
    bleeding_out        = 'Bleeding Out',
    cardiac_arrest      = 'Cardiac Arrest',
    severe_trauma       = 'Severe Trauma',
    head_injury         = 'Head Trauma',
    gunshot_wound       = 'Gunshot Wound',
    vehicle_crash       = 'Vehicle Crash',

    -- ─── DEATH MENU ────────────────────────────────────────────────
    menu_title              = '🚨 Emergency Status',
    menu_vitals             = 'Vital Signs',
    menu_vitals_desc        = '❤️ %s  |  🩸 %d%%  |  ⏱ %s',
    menu_status_dead        = 'Condition Critical',
    menu_call_ambulance     = '🚑 Call Ambulance',
    menu_call_cost          = 'Emergency dispatch fee: $%d',
    menu_ambulance_enroute  = '🚑 Ambulance En Route',
    menu_ambulance_dist     = 'ETA ~%ds · Distance: %dm',
    menu_ambulance_wait     = 'Help is on the way — stay down',
    menu_respawn            = '🏥 Respawn at Hospital',
    menu_respawn_desc       = 'Give up and wake up at nearest medical center',
    menu_respawn_locked     = '🔒 Respawn Locked — %ds remaining',
    menu_respawn_locked_desc= 'Hang in there, help might come',

    -- ─── NOTIFICATIONS ─────────────────────────────────────────────
    revived_success         = 'You have been stabilized and revived!',
    respawned               = 'You woke up at %s',
    doctor_called           = 'AI Ambulance Dispatched!',
    doctor_called_desc      = 'ETA ~%ds · Fee: $%d charged',
    doctor_arrived          = 'Paramedics On Scene',
    doctor_treating         = '⚕ Emergency Treatment in Progress...',
    doctor_success          = '✅ Stabilized & Revived!',
    doctor_failed           = '❌ Paramedic could not reach you',
    service_unavailable     = 'No ambulance available in your area',
    too_far                 = 'Location too remote for emergency services',
    no_money                = 'Insufficient Funds — Need $%d more',
    payment_failed          = 'Unable to process payment',
    admin_revived_by        = 'You were revived by an administrator',
    admin_revived_target    = '%s has been revived',
}