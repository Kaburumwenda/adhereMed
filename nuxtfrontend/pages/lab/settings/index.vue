<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-cog-outline</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Lab settings</div>
        <div class="text-body-2 text-medium-emphasis">
          Configure your lab profile, operations, localization &amp; preferences
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="loading" @click="loadAll">Refresh</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-content-save-outline"
             :loading="saving" :disabled="!dirty" @click="saveAll">
        Save changes
      </v-btn>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-1">
      <v-col v-for="k in kpiTiles" :key="k.label" cols="6" md="3">
        <v-card flat rounded="lg" class="kpi pa-3"
                @click="k.tab && (tab = k.tab)" style="cursor: pointer">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="36" class="mr-2">
              <v-icon :color="k.color + '-darken-2'" size="20">{{ k.icon }}</v-icon>
            </v-avatar>
            <div class="min-width-0">
              <div class="text-overline text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption text-medium-emphasis">{{ k.sub }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Section pills -->
    <v-card flat rounded="lg" class="section-pills pa-2 my-3">
      <v-chip-group v-model="tab" mandatory selected-class="text-primary">
        <v-chip v-for="s in sectionPills" :key="s.value" :value="s.value"
                filter variant="tonal" :color="s.color">
          <v-icon size="16" start>{{ s.icon }}</v-icon>{{ s.label }}
        </v-chip>
      </v-chip-group>
    </v-card>

    <v-row v-if="loading" justify="center" class="my-12">
      <v-progress-circular indeterminate color="primary" size="40" />
    </v-row>

    <!-- ────────── Profile tab ────────── -->
    <template v-else-if="tab === 'profile'">
      <v-row dense>
        <v-col cols="12" md="4">
          <v-card flat rounded="lg" class="section-card pa-4 text-center">
            <div class="text-overline text-medium-emphasis mb-2">Lab logo</div>
            <div class="logo-frame mx-auto">
              <img v-if="logoPreview || form.logo_url" :src="logoPreview || form.logo_url" alt="Logo" />
              <div v-else class="text-disabled">
                <v-icon size="64" color="grey-lighten-1">mdi-image-outline</v-icon>
                <div class="text-caption mt-1">No logo uploaded</div>
              </div>
            </div>
            <v-file-input v-model="logoFile" accept="image/*"
                          label="Choose logo" prepend-icon=""
                          prepend-inner-icon="mdi-image-plus"
                          variant="outlined" density="compact" rounded="lg"
                          persistent-placeholder hide-details show-size class="mt-3"
                          @update:model-value="onLogoPicked" />
            <div class="d-flex ga-2 mt-3 justify-center">
              <v-btn :disabled="!logoFile" :loading="uploadingLogo"
                     color="primary" rounded="lg" prepend-icon="mdi-cloud-upload"
                     size="small" @click="uploadLogo">Upload</v-btn>
              <v-btn v-if="form.logo_url" variant="text" color="error"
                     size="small" prepend-icon="mdi-delete"
                     @click="clearLogo">Remove</v-btn>
            </div>
            <div class="text-caption text-medium-emphasis mt-2">
              PNG / JPG · transparent background recommended
            </div>
          </v-card>
        </v-col>
        <v-col cols="12" md="8">
          <v-card flat rounded="lg" class="section-card pa-4">
            <div class="text-overline text-medium-emphasis mb-3">Identity</div>
            <v-row dense>
              <v-col cols="12" md="8">
                <v-text-field v-model="form.name" label="Lab name *"
                              placeholder="e.g. AfyaOne Diagnostics Lab"
                              variant="outlined" density="compact" rounded="lg"
                              persistent-placeholder hide-details="auto"
                              :rules="[v => !!v || 'Name is required']"
                              @update:model-value="markDirty">
                  <template #prepend-inner>
                    <v-icon size="18" color="indigo-darken-2">mdi-domain</v-icon>
                  </template>
                </v-text-field>
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field v-model="form.license_number" label="License number"
                              placeholder="LIC-XXXXX"
                              variant="outlined" density="compact" rounded="lg"
                              persistent-placeholder hide-details
                              @update:model-value="markDirty">
                  <template #prepend-inner>
                    <v-icon size="18" color="indigo-darken-2">mdi-certificate</v-icon>
                  </template>
                </v-text-field>
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.description" label="About the lab"
                            placeholder="Short description shown on reports / patient portal…"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details rows="3" auto-grow
                            @update:model-value="markDirty" />
              </v-col>
            </v-row>

            <v-divider class="my-4" />
            <div class="text-overline text-medium-emphasis mb-2">Contact</div>
            <v-row dense>
              <v-col cols="12" md="4">
                <v-text-field v-model="contact.phone" label="Phone"
                              placeholder="+254 700 000000"
                              variant="outlined" density="compact" rounded="lg"
                              persistent-placeholder hide-details
                              @update:model-value="markPrefDirty">
                  <template #prepend-inner>
                    <v-icon size="18" color="indigo-darken-2">mdi-phone</v-icon>
                  </template>
                </v-text-field>
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field v-model="contact.email" label="Email"
                              placeholder="info@yourlab.co.ke"
                              variant="outlined" density="compact" rounded="lg"
                              persistent-placeholder hide-details
                              @update:model-value="markPrefDirty">
                  <template #prepend-inner>
                    <v-icon size="18" color="indigo-darken-2">mdi-email</v-icon>
                  </template>
                </v-text-field>
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field v-model="contact.website" label="Website"
                              placeholder="https://yourlab.co.ke"
                              variant="outlined" density="compact" rounded="lg"
                              persistent-placeholder hide-details
                              @update:model-value="markPrefDirty">
                  <template #prepend-inner>
                    <v-icon size="18" color="indigo-darken-2">mdi-web</v-icon>
                  </template>
                </v-text-field>
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="contact.address" label="Address"
                            placeholder="P.O. Box 12345, Nairobi, Kenya"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details rows="2" auto-grow
                            @update:model-value="markPrefDirty" />
              </v-col>
            </v-row>
            <v-alert type="info" variant="tonal" density="compact" class="mt-3">
              Contact details are stored locally and used on print headers / footers.
              For domain-level changes contact your administrator.
            </v-alert>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <!-- ────────── Operations tab ────────── -->
    <template v-else-if="tab === 'operations'">
      <v-card flat rounded="lg" class="section-card pa-4 mb-3">
        <div class="d-flex align-center mb-3 flex-wrap ga-2">
          <v-icon color="indigo-darken-2">mdi-clock-outline</v-icon>
          <div class="text-subtitle-1 font-weight-bold">Operating hours</div>
          <v-spacer />
          <v-menu>
            <template #activator="{ props }">
              <v-btn v-bind="props" size="small" variant="tonal" rounded="lg"
                     prepend-icon="mdi-flash">Quick presets</v-btn>
            </template>
            <v-list density="compact">
              <v-list-item @click="applyHoursPreset('weekdays')"
                           prepend-icon="mdi-briefcase" title="Weekdays 8–5 · Sat 9–1 · Sun off" />
              <v-list-item @click="applyHoursPreset('extended')"
                           prepend-icon="mdi-clock-fast" title="Mon–Sat 7–8 · Sun 9–4" />
              <v-list-item @click="applyHoursPreset('twentyfour')"
                           prepend-icon="mdi-hours-24" title="24/7 every day" />
              <v-list-item @click="applyHoursPreset('clear')"
                           prepend-icon="mdi-close-circle-outline" title="Clear all" />
            </v-list>
          </v-menu>
        </div>
        <v-row dense>
          <v-col v-for="d in dayKeys" :key="d.key" cols="12" md="6" lg="4">
            <v-card flat rounded="lg" class="hours-card pa-3">
              <div class="d-flex align-center">
                <v-icon size="18" color="indigo-darken-2" class="mr-2">mdi-calendar-today</v-icon>
                <div class="font-weight-medium">{{ d.label }}</div>
                <v-spacer />
                <v-switch v-model="hoursState[d.key].open" inset color="success"
                          density="compact" hide-details
                          @update:model-value="markDirty" />
              </div>
              <v-row dense class="mt-1" v-if="hoursState[d.key].open">
                <v-col cols="6">
                  <v-text-field v-model="hoursState[d.key].from" type="time"
                                label="From" variant="outlined" density="compact"
                                rounded="lg" hide-details
                                @update:model-value="markDirty" />
                </v-col>
                <v-col cols="6">
                  <v-text-field v-model="hoursState[d.key].to" type="time"
                                label="To" variant="outlined" density="compact"
                                rounded="lg" hide-details
                                @update:model-value="markDirty" />
                </v-col>
              </v-row>
              <div v-else class="text-caption text-disabled mt-2">Closed</div>
            </v-card>
          </v-col>
        </v-row>
      </v-card>

      <v-card flat rounded="lg" class="section-card pa-4 mb-3">
        <div class="d-flex align-center mb-3">
          <v-icon color="teal-darken-2">mdi-medical-bag</v-icon>
          <div class="text-subtitle-1 font-weight-bold ml-2">Services offered</div>
          <v-spacer />
          <span class="text-caption text-medium-emphasis">
            {{ form.services?.length || 0 }} selected
          </span>
        </div>
        <v-combobox v-model="form.services" :items="serviceSuggestions"
                    label="Services" placeholder="Add or pick a service…"
                    variant="outlined" density="compact" rounded="lg"
                    persistent-placeholder hide-details multiple chips closable-chips
                    @update:model-value="markDirty" />
        <div class="d-flex flex-wrap ga-1 mt-2">
          <span class="text-caption text-medium-emphasis mr-1">Quick add:</span>
          <v-chip v-for="s in serviceSuggestions" :key="s"
                  size="x-small" variant="outlined" style="cursor: pointer"
                  :disabled="form.services?.includes(s)"
                  @click="addService(s)">
            <v-icon size="12" start>mdi-plus</v-icon>{{ s }}
          </v-chip>
        </div>
      </v-card>

      <v-card flat rounded="lg" class="section-card pa-4 mb-3">
        <div class="d-flex align-center mb-3">
          <v-icon color="green-darken-2">mdi-shield-account</v-icon>
          <div class="text-subtitle-1 font-weight-bold ml-2">Insurance</div>
          <v-spacer />
          <v-switch v-model="form.accepts_insurance" inset color="success"
                    density="compact" hide-details label="Accept insurance"
                    @update:model-value="markDirty" />
        </div>
        <v-combobox v-if="form.accepts_insurance" v-model="form.insurance_providers"
                    :items="insurerSuggestions"
                    label="Accepted insurers" placeholder="Add an insurer…"
                    variant="outlined" density="compact" rounded="lg"
                    persistent-placeholder hide-details multiple chips closable-chips
                    @update:model-value="markDirty" />
        <v-alert v-else type="info" variant="tonal" density="compact" class="mt-1">
          Insurance handling is disabled. Patients will be billed directly.
        </v-alert>
      </v-card>

      <v-card flat rounded="lg" class="section-card pa-4">
        <div class="d-flex align-center mb-3">
          <v-icon color="orange-darken-2">mdi-truck-fast</v-icon>
          <div class="text-subtitle-1 font-weight-bold ml-2">Sample collection</div>
        </div>
        <v-row dense>
          <v-col cols="12" md="6">
            <v-text-field v-model.number="form.delivery_radius_km" type="number" min="0" step="0.5"
                          label="Home-collection radius (km)"
                          variant="outlined" density="compact" rounded="lg"
                          persistent-placeholder hide-details suffix="km"
                          @update:model-value="markDirty" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model.number="form.delivery_fee" type="number" min="0" step="50"
                          :label="`Collection fee (${prefs.currency})`"
                          variant="outlined" density="compact" rounded="lg"
                          persistent-placeholder hide-details :prefix="prefs.currency"
                          @update:model-value="markDirty" />
          </v-col>
        </v-row>
      </v-card>
    </template>

    <!-- ────────── Localization tab ────────── -->
    <template v-else-if="tab === 'localization'">
      <v-card flat rounded="lg" class="section-card pa-4 mb-3">
        <div class="text-overline text-medium-emphasis mb-3">Regional settings</div>
        <v-row dense>
          <v-col cols="12" md="4">
            <v-select v-model="prefs.currency" :items="currencyItems"
                      label="Currency" variant="outlined" density="compact" rounded="lg"
                      persistent-placeholder hide-details
                      @update:model-value="markPrefDirty">
              <template #prepend-inner>
                <v-icon size="18" color="indigo-darken-2">mdi-currency-usd</v-icon>
              </template>
            </v-select>
          </v-col>
          <v-col cols="12" md="4">
            <v-autocomplete v-model="prefs.timezone" :items="timezoneItems"
                            label="Timezone" variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details
                            @update:model-value="markPrefDirty">
              <template #prepend-inner>
                <v-icon size="18" color="indigo-darken-2">mdi-earth</v-icon>
              </template>
            </v-autocomplete>
          </v-col>
          <v-col cols="12" md="4">
            <v-select v-model="prefs.dateFormat" :items="dateFormatItems"
                      label="Date format" variant="outlined" density="compact" rounded="lg"
                      persistent-placeholder hide-details
                      @update:model-value="markPrefDirty">
              <template #prepend-inner>
                <v-icon size="18" color="indigo-darken-2">mdi-calendar</v-icon>
              </template>
            </v-select>
          </v-col>
          <v-col cols="12" md="4">
            <v-select v-model="prefs.timeFormat" :items="timeFormatItems"
                      label="Time format" variant="outlined" density="compact" rounded="lg"
                      persistent-placeholder hide-details
                      @update:model-value="markPrefDirty" />
          </v-col>
          <v-col cols="12" md="4">
            <v-select v-model="prefs.weekStart" :items="weekStartItems"
                      label="Week starts on" variant="outlined" density="compact" rounded="lg"
                      persistent-placeholder hide-details
                      @update:model-value="markPrefDirty" />
          </v-col>
          <v-col cols="12" md="4">
            <v-select v-model="prefs.language" :items="languageItems"
                      label="Language" variant="outlined" density="compact" rounded="lg"
                      persistent-placeholder hide-details
                      @update:model-value="markPrefDirty" />
          </v-col>
        </v-row>
      </v-card>

      <v-card flat rounded="lg" class="section-card pa-4">
        <div class="text-overline text-medium-emphasis mb-2">Tax &amp; numbering</div>
        <v-row dense>
          <v-col cols="12" md="4">
            <v-text-field v-model.number="prefs.taxRate" type="number" min="0" max="50" step="0.5"
                          label="Default tax rate (VAT %)"
                          variant="outlined" density="compact" rounded="lg"
                          persistent-placeholder hide-details suffix="%"
                          @update:model-value="markPrefDirty" />
          </v-col>
          <v-col cols="12" md="4">
            <v-text-field v-model="prefs.invoicePrefix" label="Invoice prefix"
                          placeholder="INV"
                          variant="outlined" density="compact" rounded="lg"
                          persistent-placeholder hide-details
                          @update:model-value="markPrefDirty" />
          </v-col>
          <v-col cols="12" md="4">
            <v-text-field v-model="prefs.accessionPrefix" label="Accession prefix"
                          placeholder="A"
                          variant="outlined" density="compact" rounded="lg"
                          persistent-placeholder hide-details
                          @update:model-value="markPrefDirty" />
          </v-col>
        </v-row>
      </v-card>
    </template>

    <!-- ────────── Appearance tab ────────── -->
    <template v-else-if="tab === 'appearance'">
      <v-card flat rounded="lg" class="section-card pa-4 mb-3">
        <div class="text-overline text-medium-emphasis mb-3">Theme</div>
        <v-row dense>
          <v-col v-for="t in themeOptions" :key="t.value" cols="6" md="3">
            <v-card flat rounded="lg" class="theme-tile pa-3 text-center"
                    :class="{ 'is-selected': prefs.theme === t.value }"
                    @click="prefs.theme = t.value; markPrefDirty()">
              <div class="theme-swatch mb-2" :style="{ background: t.preview }">
                <v-icon size="22" :color="t.iconColor">{{ t.icon }}</v-icon>
              </div>
              <div class="text-body-2 font-weight-medium">{{ t.label }}</div>
              <v-icon v-if="prefs.theme === t.value" color="success" size="18" class="mt-1">
                mdi-check-circle
              </v-icon>
            </v-card>
          </v-col>
        </v-row>
      </v-card>

      <v-card flat rounded="lg" class="section-card pa-4 mb-3">
        <div class="text-overline text-medium-emphasis mb-2">Layout density</div>
        <v-btn-toggle v-model="prefs.density" mandatory color="indigo" rounded="lg"
                      density="compact" @update:model-value="markPrefDirty">
          <v-btn value="compact" prepend-icon="mdi-format-line-spacing">Compact</v-btn>
          <v-btn value="comfortable" prepend-icon="mdi-view-sequential">Comfortable</v-btn>
          <v-btn value="spacious" prepend-icon="mdi-view-stream">Spacious</v-btn>
        </v-btn-toggle>
      </v-card>

      <v-card flat rounded="lg" class="section-card pa-4">
        <div class="text-overline text-medium-emphasis mb-2">Sidebar</div>
        <v-switch v-model="prefs.sidebarCollapsed" inset color="indigo"
                  density="compact" hide-details
                  label="Start sidebar collapsed by default"
                  @update:model-value="markPrefDirty" />
        <v-switch v-model="prefs.showAvatars" inset color="indigo"
                  density="compact" hide-details
                  label="Show avatars on tables / lists"
                  @update:model-value="markPrefDirty" />
      </v-card>
    </template>

    <!-- ────────── Notifications tab ────────── -->
    <template v-else-if="tab === 'notifications'">
      <v-card flat rounded="lg" class="section-card pa-4 mb-3">
        <div class="text-overline text-medium-emphasis mb-2">Inbox behaviour</div>
        <v-switch v-model="notifPrefs.autoRefresh" inset color="indigo"
                  density="compact" hide-details
                  label="Auto-refresh inbox every 60s"
                  @update:model-value="markPrefDirty" />
        <v-switch v-model="notifPrefs.desktop" inset color="indigo"
                  density="compact" hide-details
                  label="Show desktop notifications (browser permission)"
                  @update:model-value="onDesktopToggle" />
        <v-switch v-model="notifPrefs.sound" inset color="indigo"
                  density="compact" hide-details
                  label="Play sound on new notifications"
                  @update:model-value="markPrefDirty" />
        <v-divider class="my-3" />
        <div class="text-overline text-medium-emphasis mb-1">Mute categories</div>
        <div class="text-caption text-medium-emphasis mb-2">
          Muted categories stay visible in the inbox but won't trigger pop-ups or sound.
        </div>
        <v-row dense>
          <v-col v-for="opt in notifTypes" :key="opt.value" cols="12" sm="6" md="4">
            <v-switch v-model="notifPrefs.muted" :value="opt.value" inset density="compact"
                      hide-details color="grey-darken-1"
                      @update:model-value="markPrefDirty">
              <template #label>
                <v-icon size="16" :color="opt.color" class="mr-1">{{ opt.icon }}</v-icon>
                {{ opt.label }}
              </template>
            </v-switch>
          </v-col>
        </v-row>
      </v-card>

      <v-card flat rounded="lg" class="section-card pa-4">
        <div class="d-flex align-center">
          <v-avatar color="indigo-lighten-5" size="36" class="mr-2">
            <v-icon color="indigo-darken-2">mdi-bell-ring</v-icon>
          </v-avatar>
          <div>
            <div class="text-body-2 font-weight-medium">Open notifications inbox</div>
            <div class="text-caption text-medium-emphasis">
              Browse, search, and manage your notifications
            </div>
          </div>
          <v-spacer />
          <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-arrow-right-circle"
                 to="/lab/notifications">Open inbox</v-btn>
        </div>
      </v-card>
    </template>

    <!-- ────────── Security tab ────────── -->
    <template v-else-if="tab === 'security'">
      <v-card flat rounded="lg" class="section-card pa-4 mb-3">
        <div class="text-overline text-medium-emphasis mb-3">Account</div>
        <v-row dense>
          <v-col cols="12" md="6">
            <v-text-field :model-value="account.email" label="Signed in as" readonly
                          variant="outlined" density="compact" rounded="lg"
                          persistent-placeholder hide-details>
              <template #prepend-inner>
                <v-icon size="18" color="indigo-darken-2">mdi-account-circle</v-icon>
              </template>
            </v-text-field>
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field :model-value="account.role" label="Role" readonly
                          variant="outlined" density="compact" rounded="lg"
                          persistent-placeholder hide-details>
              <template #prepend-inner>
                <v-icon size="18" color="indigo-darken-2">mdi-shield-account</v-icon>
              </template>
            </v-text-field>
          </v-col>
        </v-row>
        <div class="d-flex flex-wrap ga-2 mt-3">
          <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-lock-reset"
                 @click="passwordDialog = true">Change password</v-btn>
          <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-account-outline"
                 to="/profile">Open profile</v-btn>
          <v-spacer />
          <v-btn variant="text" color="error" rounded="lg" prepend-icon="mdi-logout"
                 @click="signOut">Sign out everywhere</v-btn>
        </div>
      </v-card>

      <v-card flat rounded="lg" class="section-card pa-4 mb-3">
        <div class="text-overline text-medium-emphasis mb-2">Session</div>
        <div class="d-flex align-center">
          <v-icon size="18" color="indigo-darken-2" class="mr-2">mdi-clock-time-eight-outline</v-icon>
          <div class="text-body-2">
            Auto-logout after
            <strong>{{ prefs.idleMinutes }} minutes</strong> of inactivity
          </div>
          <v-spacer />
          <v-slider v-model="prefs.idleMinutes" :min="5" :max="120" :step="5"
                    style="max-width: 260px" hide-details density="compact"
                    @update:model-value="markPrefDirty" />
        </div>
      </v-card>

      <v-card flat rounded="lg" class="section-card pa-4">
        <div class="text-overline text-medium-emphasis mb-2">Danger zone</div>
        <v-alert type="warning" variant="tonal" density="compact" class="mb-3">
          Resetting preferences only affects this device's local settings. Server-side
          profile data is unaffected.
        </v-alert>
        <v-btn variant="outlined" color="warning" rounded="lg"
               prepend-icon="mdi-restore" @click="resetLocalPrefs">
          Reset local preferences
        </v-btn>
      </v-card>
    </template>

    <!-- ────────── About tab ────────── -->
    <template v-else-if="tab === 'about'">
      <v-card flat rounded="lg" class="section-card pa-4 mb-3">
        <div class="d-flex align-center mb-3">
          <v-avatar color="indigo-lighten-5" size="48" class="mr-3">
            <v-icon color="indigo-darken-2" size="28">mdi-flask</v-icon>
          </v-avatar>
          <div>
            <div class="text-h6 font-weight-bold">AfyaOne · Lab module</div>
            <div class="text-caption text-medium-emphasis">
              Modern lab operations management
            </div>
          </div>
        </div>
        <v-divider class="mb-3" />
        <v-row dense>
          <v-col cols="6" md="3">
            <div class="text-overline text-medium-emphasis">Version</div>
            <div class="text-body-2 font-weight-medium">v1.0.0</div>
          </v-col>
          <v-col cols="6" md="3">
            <div class="text-overline text-medium-emphasis">Build</div>
            <div class="text-body-2 font-weight-medium">{{ buildDate }}</div>
          </v-col>
          <v-col cols="6" md="3">
            <div class="text-overline text-medium-emphasis">Tenant</div>
            <div class="text-body-2 font-weight-medium">{{ form.name || '—' }}</div>
          </v-col>
          <v-col cols="6" md="3">
            <div class="text-overline text-medium-emphasis">License</div>
            <div class="text-body-2 font-weight-medium">{{ form.license_number || '—' }}</div>
          </v-col>
        </v-row>
      </v-card>

      <v-card flat rounded="lg" class="section-card pa-4">
        <div class="text-overline text-medium-emphasis mb-3">Quick links</div>
        <v-row dense>
          <v-col v-for="l in quickLinks" :key="l.path" cols="6" md="3">
            <v-card flat rounded="lg" class="quick-link pa-3 h-100" :to="l.path">
              <v-icon size="28" :color="l.color">{{ l.icon }}</v-icon>
              <div class="text-body-2 font-weight-medium mt-2">{{ l.label }}</div>
              <div class="text-caption text-medium-emphasis">{{ l.sub }}</div>
            </v-card>
          </v-col>
        </v-row>
      </v-card>
    </template>

    <!-- Password dialog -->
    <v-dialog v-model="passwordDialog" max-width="480" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="indigo-lighten-5" size="40" class="mr-3">
            <v-icon color="indigo-darken-2">mdi-lock-reset</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">Security</div>
            <div class="text-h6 font-weight-bold">Change password</div>
          </div>
          <v-spacer />
          <v-btn icon variant="text" size="small" @click="passwordDialog = false">
            <v-icon>mdi-close</v-icon>
          </v-btn>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-text-field v-model="pwForm.current" label="Current password"
                        :type="pwShow.current ? 'text' : 'password'"
                        :append-inner-icon="pwShow.current ? 'mdi-eye-off' : 'mdi-eye'"
                        @click:append-inner="pwShow.current = !pwShow.current"
                        variant="outlined" density="compact" rounded="lg"
                        persistent-placeholder hide-details class="mb-3" />
          <v-text-field v-model="pwForm.next" label="New password"
                        :type="pwShow.next ? 'text' : 'password'"
                        :append-inner-icon="pwShow.next ? 'mdi-eye-off' : 'mdi-eye'"
                        @click:append-inner="pwShow.next = !pwShow.next"
                        variant="outlined" density="compact" rounded="lg"
                        persistent-placeholder hide-details class="mb-1" />
          <v-progress-linear :model-value="pwStrength.score * 25"
                             :color="pwStrength.color" height="6" rounded class="mb-1" />
          <div class="text-caption" :class="`text-${pwStrength.color}-darken-2`">
            {{ pwStrength.label }}
          </div>
          <v-text-field v-model="pwForm.confirm" label="Confirm new password"
                        :type="pwShow.confirm ? 'text' : 'password'"
                        :append-inner-icon="pwShow.confirm ? 'mdi-eye-off' : 'mdi-eye'"
                        @click:append-inner="pwShow.confirm = !pwShow.confirm"
                        :error-messages="pwForm.confirm && pwForm.confirm !== pwForm.next ? ['Passwords do not match'] : []"
                        variant="outlined" density="compact" rounded="lg"
                        persistent-placeholder hide-details="auto" class="mt-3" />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="passwordDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" :loading="changingPw"
                 prepend-icon="mdi-content-save-outline"
                 :disabled="!pwForm.current || !pwForm.next || pwForm.next !== pwForm.confirm"
                 @click="changePassword">Update password</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" :timeout="2400">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'

const { $api } = useNuxtApp()
const router = useRouter()

// ── State ───────────────────────────────────────────────
const loading = ref(false)
const saving = ref(false)
const uploadingLogo = ref(false)
const dirty = ref(false)
const tab = ref('profile')

const sectionPills = [
  { value: 'profile',       label: 'Profile',       color: 'indigo',          icon: 'mdi-domain' },
  { value: 'operations',    label: 'Operations',    color: 'teal',            icon: 'mdi-clock-outline' },
  { value: 'localization',  label: 'Localization',  color: 'deep-purple',     icon: 'mdi-earth' },
  { value: 'appearance',    label: 'Appearance',    color: 'pink',            icon: 'mdi-palette' },
  { value: 'notifications', label: 'Notifications', color: 'amber-darken-2',  icon: 'mdi-bell' },
  { value: 'security',      label: 'Security',      color: 'red',             icon: 'mdi-shield-check' },
  { value: 'about',         label: 'About',         color: 'grey',            icon: 'mdi-information' },
]

const dayKeys = [
  { key: 'mon', label: 'Monday' },
  { key: 'tue', label: 'Tuesday' },
  { key: 'wed', label: 'Wednesday' },
  { key: 'thu', label: 'Thursday' },
  { key: 'fri', label: 'Friday' },
  { key: 'sat', label: 'Saturday' },
  { key: 'sun', label: 'Sunday' },
]

const serviceSuggestions = [
  'Phlebotomy', 'Home collection', 'STAT testing', 'Walk-in service',
  'Online reports', 'WhatsApp delivery', 'Histopathology', 'Microbiology',
  'PCR testing', 'Imaging', 'Pre-employment screening', 'Wellness packages',
]
const insurerSuggestions = [
  'NHIF', 'AAR', 'Jubilee', 'Britam', 'CIC', 'Madison', 'APA',
  'Heritage', 'Old Mutual', 'Sanlam', 'Resolution', 'UAP',
]

// ── Form (server-backed) ───────────────────────────────
const form = reactive({
  id: null,
  name: '',
  license_number: '',
  description: '',
  logo_url: '',
  services: [],
  accepts_insurance: false,
  insurance_providers: [],
  delivery_radius_km: 0,
  delivery_fee: 0,
  operating_hours: {},
})

const hoursState = reactive({})
dayKeys.forEach(d => { hoursState[d.key] = { open: false, from: '08:00', to: '17:00' } })

// ── Local preferences (browser-side) ───────────────────
const PREFS_KEY = 'lab.settings.prefs'
const NOTIF_KEY = 'lab.notifications.prefs'

const prefs = reactive({
  currency: 'KES',
  timezone: 'Africa/Nairobi',
  dateFormat: 'dd MMM yyyy',
  timeFormat: '24h',
  weekStart: 'monday',
  language: 'en',
  taxRate: 16,
  invoicePrefix: 'INV',
  accessionPrefix: 'A',
  theme: 'light',
  density: 'comfortable',
  sidebarCollapsed: false,
  showAvatars: true,
  idleMinutes: 30,
})
const contact = reactive({ phone: '', email: '', website: '', address: '' })
const notifPrefs = reactive({ autoRefresh: true, desktop: false, sound: false, muted: [] })

const currencyItems = [
  { title: 'KES — Kenyan Shilling', value: 'KES' },
  { title: 'USD — US Dollar', value: 'USD' },
  { title: 'EUR — Euro', value: 'EUR' },
  { title: 'GBP — British Pound', value: 'GBP' },
  { title: 'TZS — Tanzanian Shilling', value: 'TZS' },
  { title: 'UGX — Ugandan Shilling', value: 'UGX' },
  { title: 'RWF — Rwandan Franc', value: 'RWF' },
  { title: 'NGN — Nigerian Naira', value: 'NGN' },
  { title: 'ZAR — South African Rand', value: 'ZAR' },
]
const timezoneItems = [
  'Africa/Nairobi', 'Africa/Dar_es_Salaam', 'Africa/Kampala', 'Africa/Kigali',
  'Africa/Lagos', 'Africa/Cairo', 'Africa/Johannesburg', 'Europe/London', 'UTC',
]
const dateFormatItems = [
  { title: '12 May 2026', value: 'dd MMM yyyy' },
  { title: '12/05/2026',  value: 'dd/MM/yyyy' },
  { title: '05/12/2026',  value: 'MM/dd/yyyy' },
  { title: '2026-05-12',  value: 'yyyy-MM-dd' },
]
const timeFormatItems = [
  { title: '24-hour (14:30)', value: '24h' },
  { title: '12-hour (2:30 PM)', value: '12h' },
]
const weekStartItems = [
  { title: 'Monday', value: 'monday' },
  { title: 'Sunday', value: 'sunday' },
  { title: 'Saturday', value: 'saturday' },
]
const languageItems = [
  { title: 'English', value: 'en' },
  { title: 'Swahili', value: 'sw' },
  { title: 'French',  value: 'fr' },
]
const themeOptions = [
  { value: 'light', label: 'Light',     preview: 'linear-gradient(135deg,#fff,#eef2ff)', icon: 'mdi-white-balance-sunny', iconColor: 'amber-darken-2' },
  { value: 'dark',  label: 'Dark',      preview: 'linear-gradient(135deg,#1e293b,#0f172a)', icon: 'mdi-weather-night', iconColor: 'amber-lighten-2' },
  { value: 'system',label: 'System',    preview: 'linear-gradient(135deg,#fff 0 50%,#1e293b 50% 100%)', icon: 'mdi-monitor', iconColor: 'indigo' },
  { value: 'mono',  label: 'Mono',      preview: 'linear-gradient(135deg,#f5f5f5,#e0e0e0)', icon: 'mdi-circle-half-full', iconColor: 'grey-darken-2' },
]
const notifTypes = [
  { value: 'appointment',  label: 'Appointment',  icon: 'mdi-calendar',     color: 'indigo' },
  { value: 'lab_result',   label: 'Lab Result',   icon: 'mdi-microscope',   color: 'purple' },
  { value: 'prescription', label: 'Prescription', icon: 'mdi-pill',         color: 'teal' },
  { value: 'billing',      label: 'Billing',      icon: 'mdi-receipt-text', color: 'amber' },
  { value: 'system',       label: 'System',       icon: 'mdi-cog',          color: 'grey' },
  { value: 'stock_alert',  label: 'Stock Alert',  icon: 'mdi-package-variant-remove', color: 'orange' },
  { value: 'escalation',   label: 'Escalation',   icon: 'mdi-alert-octagon', color: 'red' },
  { value: 'consent',      label: 'Consent',      icon: 'mdi-file-document-check', color: 'brown' },
]

const buildDate = new Date().toISOString().slice(0, 10)
const quickLinks = [
  { label: 'Branches',         path: '/lab/branches',        icon: 'mdi-bank',         color: 'teal-darken-2',     sub: 'Sites & locations' },
  { label: 'Staff',            path: '/lab/staff',           icon: 'mdi-account-group', color: 'indigo-darken-2',  sub: 'Manage team' },
  { label: 'Report templates', path: '/lab/report-templates', icon: 'mdi-printer-pos',  color: 'deep-purple-darken-2', sub: 'Print layouts' },
  { label: 'Notifications',    path: '/lab/notifications',   icon: 'mdi-bell',         color: 'amber-darken-2',    sub: 'Inbox & alerts' },
]

// ── KPI tiles ───────────────────────────────────────────
const kpiTiles = computed(() => [
  { label: 'Profile completion', value: `${profileCompletion.value}%`,
    sub: profileCompletion.value === 100 ? 'All set' : 'Add missing details',
    icon: 'mdi-check-decagram', color: 'green', tab: 'profile' },
  { label: 'Open days', value: openDaysCount.value,
    sub: `${7 - openDaysCount.value} closed`, icon: 'mdi-clock-outline',
    color: 'teal', tab: 'operations' },
  { label: 'Services', value: form.services?.length || 0,
    sub: 'Listed for patients', icon: 'mdi-medical-bag', color: 'indigo', tab: 'operations' },
  { label: 'Insurers', value: form.insurance_providers?.length || 0,
    sub: form.accepts_insurance ? 'Accepted' : 'Not accepting', icon: 'mdi-shield-account',
    color: 'deep-purple', tab: 'operations' },
])

const profileCompletion = computed(() => {
  const checks = [
    !!form.name, !!form.license_number, !!form.description, !!form.logo_url,
    !!contact.phone, !!contact.email, !!contact.address,
    (form.services?.length || 0) > 0, openDaysCount.value > 0,
  ]
  const done = checks.filter(Boolean).length
  return Math.round((done / checks.length) * 100)
})
const openDaysCount = computed(() =>
  dayKeys.filter(d => hoursState[d.key]?.open).length,
)

// ── Loading ─────────────────────────────────────────────
async function loadAll() {
  loading.value = true
  try {
    const { data } = await $api.get('/pharmacy-profile/profile/', { params: { page_size: 1 } })
    const list = data?.results || data || []
    const profile = Array.isArray(list) ? list[0] : list
    if (profile) {
      Object.assign(form, {
        id: profile.id,
        name: profile.name || '',
        license_number: profile.license_number || '',
        description: profile.description || '',
        logo_url: profile.logo_url || '',
        services: Array.isArray(profile.services) ? profile.services : [],
        accepts_insurance: !!profile.accepts_insurance,
        insurance_providers: Array.isArray(profile.insurance_providers) ? profile.insurance_providers : [],
        delivery_radius_km: Number(profile.delivery_radius_km || 0),
        delivery_fee: Number(profile.delivery_fee || 0),
        operating_hours: profile.operating_hours || {},
      })
      hydrateHours(profile.operating_hours || {})
    }
  } catch (e) {
    notify(extractError(e) || 'Failed to load lab profile', 'error')
  } finally {
    loading.value = false
    loadPrefs()
    dirty.value = false
  }
}
onMounted(loadAll)

function hydrateHours(json) {
  dayKeys.forEach(d => {
    const v = json?.[d.key]
    if (v && (v.open === true || (v.from && v.to))) {
      hoursState[d.key] = {
        open: v.open !== false,
        from: v.from || '08:00',
        to: v.to || '17:00',
      }
    }
  })
}

function serializeHours() {
  const out = {}
  dayKeys.forEach(d => {
    const s = hoursState[d.key]
    out[d.key] = s.open
      ? { open: true, from: s.from, to: s.to }
      : { open: false }
  })
  return out
}

function loadPrefs() {
  try {
    const raw = localStorage.getItem(PREFS_KEY)
    if (raw) {
      const parsed = JSON.parse(raw)
      Object.assign(prefs, parsed.prefs || {})
      Object.assign(contact, parsed.contact || {})
    }
    const nraw = localStorage.getItem(NOTIF_KEY)
    if (nraw) Object.assign(notifPrefs, JSON.parse(nraw))
  } catch (_) {}
}
function persistPrefs() {
  try {
    localStorage.setItem(PREFS_KEY, JSON.stringify({ prefs, contact }))
    localStorage.setItem(NOTIF_KEY, JSON.stringify(notifPrefs))
  } catch (_) {}
}

function markDirty() { dirty.value = true }
function markPrefDirty() { dirty.value = true }

// ── Save (server + local) ──────────────────────────────
async function saveAll() {
  saving.value = true
  try {
    if (form.id) {
      await $api.patch(`/pharmacy-profile/profile/${form.id}/`, {
        name: form.name,
        license_number: form.license_number || '',
        description: form.description || '',
        services: form.services || [],
        accepts_insurance: !!form.accepts_insurance,
        insurance_providers: form.insurance_providers || [],
        delivery_radius_km: form.delivery_radius_km || 0,
        delivery_fee: form.delivery_fee || 0,
        operating_hours: serializeHours(),
      })
    } else if (form.name) {
      const { data } = await $api.post('/pharmacy-profile/profile/', {
        name: form.name,
        license_number: form.license_number || '',
        description: form.description || '',
        services: form.services || [],
        accepts_insurance: !!form.accepts_insurance,
        insurance_providers: form.insurance_providers || [],
        delivery_radius_km: form.delivery_radius_km || 0,
        delivery_fee: form.delivery_fee || 0,
        operating_hours: serializeHours(),
      })
      form.id = data?.id
    }
    persistPrefs()
    dirty.value = false
    notify('Settings saved', 'success')
  } catch (e) {
    notify(extractError(e) || 'Save failed', 'error')
  } finally { saving.value = false }
}

// ── Logo ───────────────────────────────────────────────
const logoFile = ref(null)
const logoPreview = ref('')
function onLogoPicked(file) {
  const f = Array.isArray(file) ? file[0] : file
  if (!f) { logoPreview.value = ''; return }
  const reader = new FileReader()
  reader.onload = (e) => { logoPreview.value = e.target.result }
  reader.readAsDataURL(f)
}
async function uploadLogo() {
  if (!logoFile.value) return
  if (!form.id) {
    notify('Save profile first to attach a logo', 'warning')
    return
  }
  uploadingLogo.value = true
  try {
    const fd = new FormData()
    const f = Array.isArray(logoFile.value) ? logoFile.value[0] : logoFile.value
    fd.append('logo', f)
    const { data } = await $api.post(
      `/pharmacy-profile/profile/${form.id}/upload-logo/`, fd,
      { headers: { 'Content-Type': 'multipart/form-data' } },
    )
    form.logo_url = data?.logo_url || ''
    logoPreview.value = ''
    logoFile.value = null
    notify('Logo updated', 'success')
  } catch (e) { notify(extractError(e) || 'Upload failed', 'error') }
  finally { uploadingLogo.value = false }
}
async function clearLogo() {
  if (!form.id) return
  try {
    const fd = new FormData()
    fd.append('logo', '')
    await $api.patch(`/pharmacy-profile/profile/${form.id}/`, fd,
      { headers: { 'Content-Type': 'multipart/form-data' } })
    form.logo_url = ''
    logoPreview.value = ''
    notify('Logo removed', 'success')
  } catch (e) { notify(extractError(e) || 'Could not remove logo', 'error') }
}

// ── Operations helpers ─────────────────────────────────
function applyHoursPreset(kind) {
  if (kind === 'weekdays') {
    ['mon', 'tue', 'wed', 'thu', 'fri'].forEach(k =>
      hoursState[k] = { open: true, from: '08:00', to: '17:00' })
    hoursState.sat = { open: true, from: '09:00', to: '13:00' }
    hoursState.sun = { open: false, from: '08:00', to: '17:00' }
  } else if (kind === 'extended') {
    ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'].forEach(k =>
      hoursState[k] = { open: true, from: '07:00', to: '20:00' })
    hoursState.sun = { open: true, from: '09:00', to: '16:00' }
  } else if (kind === 'twentyfour') {
    dayKeys.forEach(d => hoursState[d.key] = { open: true, from: '00:00', to: '23:59' })
  } else if (kind === 'clear') {
    dayKeys.forEach(d => hoursState[d.key] = { open: false, from: '08:00', to: '17:00' })
  }
  markDirty()
}
function addService(s) {
  if (!form.services) form.services = []
  if (!form.services.includes(s)) { form.services.push(s); markDirty() }
}

// ── Notifications helpers ──────────────────────────────
function onDesktopToggle(v) {
  markPrefDirty()
  if (v && 'Notification' in window && Notification.permission !== 'granted') {
    Notification.requestPermission().then(p => {
      if (p !== 'granted') notifPrefs.desktop = false
    })
  }
}

// ── Security ───────────────────────────────────────────
const account = reactive({ email: '', role: '' })
const passwordDialog = ref(false)
const changingPw = ref(false)
const pwForm = reactive({ current: '', next: '', confirm: '' })
const pwShow = reactive({ current: false, next: false, confirm: false })

const pwStrength = computed(() => {
  const p = pwForm.next || ''
  let score = 0
  if (p.length >= 8) score++
  if (/[A-Z]/.test(p) && /[a-z]/.test(p)) score++
  if (/\d/.test(p)) score++
  if (/[^A-Za-z0-9]/.test(p)) score++
  const labels = ['Too short', 'Weak', 'Okay', 'Strong', 'Excellent']
  const colors = ['error', 'error', 'warning', 'success', 'success']
  return { score, label: labels[score], color: colors[score] }
})

async function changePassword() {
  if (pwForm.next !== pwForm.confirm) return
  changingPw.value = true
  try {
    await $api.post('/auth/change-password/', {
      current_password: pwForm.current,
      new_password: pwForm.next,
    })
    notify('Password updated', 'success')
    passwordDialog.value = false
    pwForm.current = pwForm.next = pwForm.confirm = ''
  } catch (e) { notify(extractError(e) || 'Password change failed', 'error') }
  finally { changingPw.value = false }
}

async function loadAccount() {
  try {
    const { data } = await $api.get('/auth/me/')
    account.email = data?.email || data?.user?.email || ''
    account.role  = (data?.role || data?.user?.role || '').replace(/_/g, ' ')
  } catch (_) {}
}
onMounted(loadAccount)

function signOut() {
  if (!confirm('Sign out from this device?')) return
  try { localStorage.removeItem('access'); localStorage.removeItem('refresh') } catch (_) {}
  router.push('/login')
}
function resetLocalPrefs() {
  if (!confirm('Reset local preferences to defaults? This will not affect server data.')) return
  try {
    localStorage.removeItem(PREFS_KEY)
    localStorage.removeItem(NOTIF_KEY)
  } catch (_) {}
  notify('Local preferences reset · reload to apply', 'success')
}

// ── Misc ───────────────────────────────────────────────
function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message || ''
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(' ') : v}`).join(' · ')
}
const snack = reactive({ show: false, color: 'success', message: '' })
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }
</script>

<style scoped>
.kpi {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.kpi:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0, 0, 0, 0.06); }
.section-card  { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.section-pills { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }

.logo-frame {
  width: 180px; height: 180px;
  border: 1px dashed rgba(0, 0, 0, 0.15);
  border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  background: #fafafa;
  overflow: hidden;
}
.logo-frame img { max-width: 100%; max-height: 100%; object-fit: contain; }

.hours-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }

.theme-tile {
  border: 2px solid transparent;
  cursor: pointer;
  transition: transform 0.12s ease, border-color 0.12s ease;
}
.theme-tile:hover { transform: translateY(-2px); }
.theme-tile.is-selected { border-color: rgba(var(--v-theme-indigo), 0.6); }
.theme-swatch {
  height: 60px;
  border-radius: 8px;
  display: flex; align-items: center; justify-content: center;
  border: 1px solid rgba(0, 0, 0, 0.06);
}

.quick-link {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
  display: block;
  text-decoration: none;
  color: inherit;
}
.quick-link:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0, 0, 0, 0.06); }

.min-width-0 { min-width: 0; }
</style>
