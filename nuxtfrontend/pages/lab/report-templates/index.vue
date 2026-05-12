<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-printer-pos</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Report templates</div>
        <div class="text-body-2 text-medium-emphasis">
          Design printable lab reports — headers, footers, signatories &amp; layout
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="loading" @click="loadAll">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
             @click="exportCsv">Export</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus"
             @click="openCreate">New template</v-btn>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-1">
      <v-col v-for="k in kpiTiles" :key="k.label" cols="6" md="3">
        <v-card flat rounded="lg" class="kpi pa-3"
                @click="k.filter && (statusFilter = k.filter)" style="cursor: pointer">
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

    <!-- ────────── Cards tab ────────── -->
    <template v-if="tab === 'cards'">
      <v-card flat rounded="lg" class="pa-3 mb-3 section-card">
        <v-row dense align="center">
          <v-col cols="12" md="5">
            <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                          placeholder="Search by name…" persistent-placeholder
                          variant="outlined" density="compact" rounded="lg"
                          hide-details clearable />
          </v-col>
          <v-col cols="6" md="3">
            <v-select v-model="deptFilter" :items="deptItems" label="Department"
                      variant="outlined" density="compact" rounded="lg"
                      persistent-placeholder hide-details clearable />
          </v-col>
          <v-col cols="6" md="3">
            <v-select v-model="statusFilter" :items="statusItems" label="Status"
                      variant="outlined" density="compact" rounded="lg"
                      persistent-placeholder hide-details />
          </v-col>
          <v-col cols="12" md="1" class="text-right">
            <v-chip color="indigo" variant="tonal" rounded="lg">
              {{ filtered.length }}
            </v-chip>
          </v-col>
        </v-row>
      </v-card>

      <v-row v-if="loading" justify="center" class="mt-6">
        <v-progress-circular indeterminate color="primary" size="40" />
      </v-row>
      <v-row v-else dense>
        <v-col v-for="t in filtered" :key="t.id" cols="12" sm="6" lg="4">
          <v-card flat rounded="lg" class="tpl-card pa-3 h-100"
                  :class="{ 'is-default': t.is_default, 'is-inactive': !t.is_active }">
            <div class="d-flex align-center mb-2">
              <v-avatar :color="t.is_default ? 'amber-lighten-5' : 'indigo-lighten-5'"
                        size="40" class="mr-3">
                <v-icon :color="t.is_default ? 'amber-darken-2' : 'indigo-darken-2'" size="22">
                  {{ t.is_default ? 'mdi-star' : 'mdi-file-document-edit' }}
                </v-icon>
              </v-avatar>
              <div class="min-width-0 flex-grow-1">
                <div class="font-weight-bold text-truncate">{{ t.name }}</div>
                <div class="text-caption text-medium-emphasis">
                  <v-chip v-if="t.is_default" size="x-small" color="amber-darken-2" variant="tonal" class="mr-1">
                    Default
                  </v-chip>
                  <v-chip size="x-small" :color="t.is_active ? 'success' : 'grey'" variant="tonal" class="mr-1">
                    {{ t.is_active ? 'Active' : 'Inactive' }}
                  </v-chip>
                  <v-chip v-if="t.department" size="x-small" variant="outlined">
                    {{ t.department }}
                  </v-chip>
                </div>
              </div>
              <v-menu>
                <template #activator="{ props }">
                  <v-btn v-bind="props" icon size="small" variant="text">
                    <v-icon size="20">mdi-dots-vertical</v-icon>
                  </v-btn>
                </template>
                <v-list density="compact">
                  <v-list-item @click="openEdit(t)" prepend-icon="mdi-pencil" title="Edit" />
                  <v-list-item @click="openPreview(t)" prepend-icon="mdi-eye" title="Preview" />
                  <v-list-item @click="duplicate(t)" prepend-icon="mdi-content-duplicate" title="Duplicate" />
                  <v-list-item v-if="!t.is_default" @click="setDefault(t)"
                               prepend-icon="mdi-star" title="Set as default" />
                  <v-list-item @click="toggleActive(t, !t.is_active)"
                               :prepend-icon="t.is_active ? 'mdi-pause-circle' : 'mdi-play-circle'"
                               :title="t.is_active ? 'Deactivate' : 'Activate'" />
                  <v-list-item @click="printTemplate(t)" prepend-icon="mdi-printer" title="Print sample" />
                  <v-divider />
                  <v-list-item @click="confirmDelete(t)" prepend-icon="mdi-delete"
                               base-color="error" title="Delete" />
                </v-list>
              </v-menu>
            </div>
            <v-divider class="mb-2" />
            <div class="tpl-thumb mb-2" v-html="thumbHtml(t)" />
            <div class="d-flex align-center text-caption text-medium-emphasis">
              <v-icon size="14" color="grey-darken-1">mdi-account-tie</v-icon>
              <span class="ml-1">
                {{ t.signatory_name || '—' }}
                <span v-if="t.signatory_title" class="text-disabled"> · {{ t.signatory_title }}</span>
              </span>
              <v-spacer />
              <v-icon v-if="t.signatory_signature" size="14" color="success" title="Signature on file">
                mdi-draw
              </v-icon>
            </div>
          </v-card>
        </v-col>
        <v-col v-if="!filtered.length" cols="12">
          <v-card flat rounded="lg" class="pa-12 text-center section-card">
            <v-icon size="64" color="grey-lighten-1">mdi-file-document-outline</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-3">No templates yet</div>
            <div class="text-body-2 text-medium-emphasis">
              Create a report template to standardize your lab printouts.
            </div>
            <v-btn class="mt-3" color="primary" rounded="lg" variant="text"
                   prepend-icon="mdi-plus" @click="openCreate">
              New template
            </v-btn>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <!-- ────────── Table tab ────────── -->
    <template v-if="tab === 'table'">
      <v-card flat rounded="lg" class="pa-3 mb-3 section-card">
        <v-row dense align="center">
          <v-col cols="12" md="5">
            <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                          placeholder="Search by name…" persistent-placeholder
                          variant="outlined" density="compact" rounded="lg"
                          hide-details clearable />
          </v-col>
          <v-col cols="6" md="3">
            <v-select v-model="deptFilter" :items="deptItems" label="Department"
                      variant="outlined" density="compact" rounded="lg"
                      persistent-placeholder hide-details clearable />
          </v-col>
          <v-col cols="6" md="3">
            <v-select v-model="statusFilter" :items="statusItems" label="Status"
                      variant="outlined" density="compact" rounded="lg"
                      persistent-placeholder hide-details />
          </v-col>
        </v-row>
      </v-card>

      <v-card flat rounded="lg" class="section-card">
        <v-data-table :headers="tableHeaders" :items="filtered" :loading="loading"
                      item-value="id" class="acct-table"
                      :items-per-page="25" :items-per-page-options="[10, 25, 50, 100]">
          <template #item.name="{ item }">
            <div class="d-flex align-center py-1">
              <v-avatar :color="item.is_default ? 'amber-lighten-5' : 'indigo-lighten-5'"
                        size="36" class="mr-3">
                <v-icon :color="item.is_default ? 'amber-darken-2' : 'indigo-darken-2'" size="20">
                  {{ item.is_default ? 'mdi-star' : 'mdi-file-document-edit' }}
                </v-icon>
              </v-avatar>
              <div class="min-width-0">
                <div class="font-weight-medium text-truncate">{{ item.name }}</div>
                <div v-if="item.is_default"
                     class="text-caption text-amber-darken-2 font-weight-medium">
                  <v-icon size="12">mdi-star</v-icon> Default template
                </div>
              </div>
            </div>
          </template>
          <template #item.department="{ item }">
            <v-chip v-if="item.department" size="x-small" variant="tonal" color="indigo">
              {{ item.department }}
            </v-chip>
            <span v-else class="text-disabled">—</span>
          </template>
          <template #item.signatory_name="{ item }">
            <div v-if="item.signatory_name">
              <div class="font-weight-medium text-body-2">{{ item.signatory_name }}</div>
              <div v-if="item.signatory_title" class="text-caption text-medium-emphasis">
                {{ item.signatory_title }}
              </div>
            </div>
            <span v-else class="text-disabled">—</span>
          </template>
          <template #item.signature="{ item }">
            <v-icon v-if="item.signatory_signature" color="success" size="20">mdi-check-circle</v-icon>
            <v-icon v-else color="grey-lighten-1" size="20">mdi-circle-outline</v-icon>
          </template>
          <template #item.is_active="{ item }">
            <v-switch :model-value="item.is_active" color="success" inset hide-details density="compact"
                      class="mt-0" @update:model-value="(v) => toggleActive(item, v)" />
          </template>
          <template #item.actions="{ item }">
            <v-btn icon size="small" variant="text"
                   :disabled="item.is_default" @click="setDefault(item)">
              <v-icon size="20" :color="item.is_default ? 'amber-darken-2' : ''">
                {{ item.is_default ? 'mdi-star' : 'mdi-star-outline' }}
              </v-icon>
              <v-tooltip activator="parent" location="top">
                {{ item.is_default ? 'Default' : 'Set as default' }}
              </v-tooltip>
            </v-btn>
            <v-btn icon size="small" variant="text" @click="openPreview(item)">
              <v-icon size="20">mdi-eye</v-icon>
              <v-tooltip activator="parent" location="top">Preview</v-tooltip>
            </v-btn>
            <v-btn icon size="small" variant="text" @click="openEdit(item)">
              <v-icon size="20">mdi-pencil</v-icon>
              <v-tooltip activator="parent" location="top">Edit</v-tooltip>
            </v-btn>
            <v-btn icon size="small" variant="text" color="error" @click="confirmDelete(item)">
              <v-icon size="20">mdi-delete</v-icon>
              <v-tooltip activator="parent" location="top">Delete</v-tooltip>
            </v-btn>
          </template>
          <template #no-data>
            <div class="text-center pa-6 text-medium-emphasis">
              <v-icon size="48" color="grey-lighten-1">mdi-file-document-outline</v-icon>
              <div class="mt-2">No templates match your filters.</div>
            </div>
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ────────── Default tab ────────── -->
    <template v-if="tab === 'default'">
      <v-card flat rounded="lg" class="section-card pa-4">
        <div class="d-flex align-center flex-wrap ga-2 mb-3">
          <v-icon color="amber-darken-2">mdi-star</v-icon>
          <div class="text-subtitle-1 font-weight-bold">Default report template</div>
          <v-spacer />
          <v-chip v-if="defaultTemplate" size="small" variant="tonal" color="amber-darken-2">
            {{ defaultTemplate.name }}
          </v-chip>
        </div>
        <v-alert v-if="!defaultTemplate" type="warning" variant="tonal" density="compact" class="mb-3">
          No default template is set. Pick one to apply when printing reports.
        </v-alert>
        <div v-if="defaultTemplate" class="report-preview" v-html="renderPreview(defaultTemplate)" />
        <div class="d-flex justify-end mt-3 ga-2" v-if="defaultTemplate">
          <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-pencil"
                 @click="openEdit(defaultTemplate)">Edit</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-printer"
                 @click="printTemplate(defaultTemplate)">Print sample</v-btn>
        </div>
      </v-card>
    </template>

    <!-- ────────── Editor dialog ────────── -->
    <v-dialog v-model="formDialog" :max-width="form.advanced ? 1200 : 880" persistent scrollable>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="indigo-lighten-5" size="40" class="mr-3">
            <v-icon color="indigo-darken-2">mdi-file-document-edit</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">
              {{ form.id ? 'Edit template' : 'New template' }}
            </div>
            <div class="text-h6 font-weight-bold">
              {{ form.id ? form.name || 'Edit template' : 'Design a report template' }}
            </div>
          </div>
          <v-spacer />
          <v-btn-toggle v-model="form.advanced" mandatory density="compact" class="mr-2"
                        color="indigo" rounded="lg">
            <v-btn :value="false" size="small" prepend-icon="mdi-form-textarea">Form</v-btn>
            <v-btn :value="true" size="small" prepend-icon="mdi-eye-arrow-right">Side-by-side</v-btn>
          </v-btn-toggle>
          <v-btn icon variant="text" size="small" @click="formDialog = false">
            <v-icon>mdi-close</v-icon>
          </v-btn>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-0">
          <v-tabs v-model="formTab" color="indigo-darken-2" align-tabs="start" density="compact" class="px-3">
            <v-tab value="basic"><v-icon size="16" start>mdi-information</v-icon>Basics</v-tab>
            <v-tab value="header"><v-icon size="16" start>mdi-page-layout-header</v-icon>Header</v-tab>
            <v-tab value="footer"><v-icon size="16" start>mdi-page-layout-footer</v-icon>Footer</v-tab>
            <v-tab value="sign"><v-icon size="16" start>mdi-draw</v-icon>Signatory</v-tab>
            <v-tab value="snippets"><v-icon size="16" start>mdi-code-tags</v-icon>Snippets</v-tab>
          </v-tabs>
          <v-divider />

          <v-row no-gutters>
            <!-- Editor side -->
            <v-col :cols="form.advanced ? 6 : 12" class="pa-4">
              <v-window v-model="formTab" class="editor-window">
                <!-- Basics -->
                <v-window-item value="basic">
                  <v-row dense>
                    <v-col cols="12" md="8">
                      <v-combobox v-model="form.name" :items="templateNameSuggestions"
                                  label="Template name *"
                                  placeholder="e.g. Standard Hematology Report"
                                  variant="outlined" density="compact" rounded="lg"
                                  persistent-placeholder hide-details="auto"
                                  :error-messages="errors.name"
                                  @update:model-value="onTemplateNamePicked">
                        <template #prepend-inner>
                          <v-icon size="18" color="indigo-darken-2">mdi-file-document-edit</v-icon>
                        </template>
                      </v-combobox>
                      <div class="mt-2 d-flex align-center flex-wrap ga-1">
                        <span class="text-caption text-medium-emphasis mr-1">Quick:</span>
                        <v-chip v-for="n in quickTemplateNames" :key="n.name"
                                size="x-small" variant="tonal" color="indigo"
                                style="cursor: pointer"
                                @click="applyNamePreset(n)">
                          {{ n.name }}
                        </v-chip>
                      </div>
                    </v-col>
                    <v-col cols="12" md="4">
                      <v-combobox v-model="form.department" :items="departmentSuggestions"
                                  label="Department" placeholder="Pick or type…"
                                  variant="outlined" density="compact" rounded="lg"
                                  persistent-placeholder hide-details clearable />
                    </v-col>
                    <v-col cols="12" md="6" class="d-flex align-center">
                      <v-switch v-model="form.is_default" inset color="amber-darken-2"
                                density="compact" hide-details
                                label="Use as default template" />
                    </v-col>
                    <v-col cols="12" md="6" class="d-flex align-center">
                      <v-switch v-model="form.is_active" inset color="success"
                                density="compact" hide-details
                                label="Active (selectable on print)" />
                    </v-col>
                    <v-col v-if="form.is_default && hasOtherDefault" cols="12">
                      <v-alert type="info" variant="tonal" density="compact">
                        Another template is currently the default. Saving will leave both flagged —
                        use "Set as default" on the cards page to switch atomically.
                      </v-alert>
                    </v-col>
                  </v-row>
                </v-window-item>

                <!-- Header -->
                <v-window-item value="header">
                  <div class="d-flex align-center flex-wrap ga-2 mb-2">
                    <div class="text-subtitle-2 font-weight-bold">Header HTML</div>
                    <v-spacer />
                    <v-btn size="x-small" variant="tonal" prepend-icon="mdi-flash"
                           @click="loadHeaderPreset('logo')">Logo + clinic</v-btn>
                    <v-btn size="x-small" variant="tonal" prepend-icon="mdi-flash"
                           @click="loadHeaderPreset('minimal')">Minimal</v-btn>
                    <v-btn size="x-small" variant="tonal" prepend-icon="mdi-flash"
                           @click="loadHeaderPreset('banded')">Branded band</v-btn>
                  </div>
                  <v-textarea v-model="form.header_html" rows="14" auto-grow
                              variant="outlined" density="compact" rounded="lg"
                              persistent-placeholder hide-details
                              placeholder="<div style=&quot;text-align:center&quot;>...</div>"
                              class="mono-input" />
                  <div class="text-caption text-medium-emphasis mt-1">
                    Tip: use the placeholders below — they will be replaced when the report is printed.
                  </div>
                </v-window-item>

                <!-- Footer -->
                <v-window-item value="footer">
                  <div class="d-flex align-center flex-wrap ga-2 mb-2">
                    <div class="text-subtitle-2 font-weight-bold">Footer HTML</div>
                    <v-spacer />
                    <v-btn size="x-small" variant="tonal" prepend-icon="mdi-flash"
                           @click="loadFooterPreset('contact')">Contact line</v-btn>
                    <v-btn size="x-small" variant="tonal" prepend-icon="mdi-flash"
                           @click="loadFooterPreset('disclaimer')">Disclaimer</v-btn>
                    <v-btn size="x-small" variant="tonal" prepend-icon="mdi-flash"
                           @click="loadFooterPreset('page')">Page number</v-btn>
                  </div>
                  <v-textarea v-model="form.footer_html" rows="10" auto-grow
                              variant="outlined" density="compact" rounded="lg"
                              persistent-placeholder hide-details
                              placeholder="<div style=&quot;font-size:11px;color:#888&quot;>...</div>"
                              class="mono-input" />
                </v-window-item>

                <!-- Signatory -->
                <v-window-item value="sign">
                  <v-row dense>
                    <v-col cols="12" md="6">
                      <v-text-field v-model="form.signatory_name" label="Signatory name"
                                    placeholder="Dr. Jane Doe"
                                    variant="outlined" density="compact" rounded="lg"
                                    persistent-placeholder hide-details>
                        <template #prepend-inner>
                          <v-icon size="18" color="indigo-darken-2">mdi-account-tie</v-icon>
                        </template>
                      </v-text-field>
                    </v-col>
                    <v-col cols="12" md="6">
                      <v-text-field v-model="form.signatory_title" label="Signatory title"
                                    placeholder="Lab Director · MBChB, MMed"
                                    variant="outlined" density="compact" rounded="lg"
                                    persistent-placeholder hide-details>
                        <template #prepend-inner>
                          <v-icon size="18" color="indigo-darken-2">mdi-certificate</v-icon>
                        </template>
                      </v-text-field>
                    </v-col>
                    <v-col cols="12">
                      <v-card flat rounded="lg" class="pa-3 notes-card">
                        <div class="d-flex align-center flex-wrap ga-2 mb-3">
                          <v-icon size="20" color="warning-darken-2" class="mr-2">mdi-draw</v-icon>
                          <div class="text-subtitle-2 font-weight-bold">Digital signature</div>
                          <v-spacer />
                          <v-btn-toggle v-model="signatureMode" mandatory density="compact"
                                        color="indigo" rounded="lg" divided>
                            <v-btn value="upload" size="small" prepend-icon="mdi-cloud-upload">Upload</v-btn>
                            <v-btn value="draw"   size="small" prepend-icon="mdi-draw-pen">Draw</v-btn>
                            <v-btn value="type"   size="small" prepend-icon="mdi-format-text">Type</v-btn>
                          </v-btn-toggle>
                        </div>

                        <!-- Upload mode -->
                        <div v-if="signatureMode === 'upload'">
                          <v-file-input v-model="signatureFile" accept="image/*"
                                        label="Upload signature image" prepend-icon=""
                                        prepend-inner-icon="mdi-image"
                                        variant="outlined" density="compact" rounded="lg"
                                        persistent-placeholder hide-details show-size
                                        @update:model-value="onSignaturePicked" />
                          <div class="text-caption text-medium-emphasis mt-1">
                            PNG / JPG · transparent background recommended
                          </div>
                        </div>

                        <!-- Draw mode -->
                        <div v-else-if="signatureMode === 'draw'">
                          <div class="signature-pad-wrap">
                            <canvas ref="padCanvas" class="signature-pad"
                                    @pointerdown="padStart" @pointermove="padMove"
                                    @pointerup="padEnd" @pointerleave="padEnd"
                                    @pointercancel="padEnd" />
                            <div v-if="padEmpty" class="signature-pad-hint">
                              Sign here with mouse, stylus or finger
                            </div>
                          </div>
                          <div class="d-flex align-center flex-wrap ga-2 mt-2">
                            <span class="text-caption text-medium-emphasis mr-1">Pen:</span>
                            <v-btn v-for="c in penColors" :key="c" icon size="x-small"
                                   :variant="penColor === c ? 'flat' : 'text'"
                                   :color="penColor === c ? 'indigo' : ''"
                                   @click="penColor = c">
                              <span class="pen-swatch" :style="{ background: c }" />
                            </v-btn>
                            <v-divider vertical class="mx-2" />
                            <span class="text-caption text-medium-emphasis mr-1">Width:</span>
                            <v-slider v-model="penWidth" :min="1" :max="6" :step="0.5"
                                      hide-details density="compact" style="max-width: 140px" />
                            <v-spacer />
                            <v-btn size="small" variant="text" prepend-icon="mdi-undo"
                                   :disabled="!padStrokes.length" @click="padUndo">Undo</v-btn>
                            <v-btn size="small" variant="text" color="error"
                                   prepend-icon="mdi-eraser" :disabled="padEmpty"
                                   @click="padClear">Clear</v-btn>
                            <v-btn size="small" color="indigo" variant="tonal"
                                   prepend-icon="mdi-check" :disabled="padEmpty"
                                   @click="padCommit">Use signature</v-btn>
                          </div>
                        </div>

                        <!-- Type mode -->
                        <div v-else-if="signatureMode === 'type'">
                          <v-row dense align="center">
                            <v-col cols="12" md="7">
                              <v-text-field v-model="typedSignature" label="Type your signature"
                                            placeholder="Dr. Jane Doe"
                                            variant="outlined" density="compact" rounded="lg"
                                            persistent-placeholder hide-details
                                            @update:model-value="renderTypedSignature" />
                            </v-col>
                            <v-col cols="12" md="5">
                              <v-select v-model="typedFont" :items="signatureFonts"
                                        label="Font style"
                                        variant="outlined" density="compact" rounded="lg"
                                        persistent-placeholder hide-details
                                        @update:model-value="renderTypedSignature" />
                            </v-col>
                          </v-row>
                          <div class="signature-typed-preview mt-3"
                               :style="{ fontFamily: typedFont, color: penColor }">
                            {{ typedSignature || 'Your signature' }}
                          </div>
                          <div class="d-flex align-center flex-wrap ga-2 mt-2">
                            <span class="text-caption text-medium-emphasis mr-1">Color:</span>
                            <v-btn v-for="c in penColors" :key="c" icon size="x-small"
                                   :variant="penColor === c ? 'flat' : 'text'"
                                   :color="penColor === c ? 'indigo' : ''"
                                   @click="penColor = c; renderTypedSignature()">
                              <span class="pen-swatch" :style="{ background: c }" />
                            </v-btn>
                            <v-spacer />
                            <v-btn size="small" color="indigo" variant="tonal"
                                   prepend-icon="mdi-check" :disabled="!typedSignature.trim()"
                                   @click="commitTypedSignature">Use signature</v-btn>
                          </div>
                          <div class="text-caption text-medium-emphasis mt-1">
                            <v-icon size="12">mdi-information-outline</v-icon>
                            Typed signatures are rendered to an image and stored like an upload.
                          </div>
                        </div>

                        <!-- Active signature preview -->
                        <v-divider class="my-3" />
                        <div class="d-flex align-center flex-wrap ga-3">
                          <div class="text-caption text-medium-emphasis">Current signature:</div>
                          <div v-if="signaturePreview || form.signatory_signature_url"
                               class="signature-preview">
                            <img :src="signaturePreview || form.signatory_signature_url" alt="Signature" />
                          </div>
                          <div v-else class="text-caption text-disabled font-italic">
                            No signature on file
                          </div>
                          <v-spacer />
                          <v-btn v-if="signaturePreview || form.signatory_signature_url"
                                 size="small" variant="text" color="error"
                                 prepend-icon="mdi-delete" @click="clearSignature">
                            Remove signature
                          </v-btn>
                        </div>
                      </v-card>
                    </v-col>
                  </v-row>
                </v-window-item>

                <!-- Snippets -->
                <v-window-item value="snippets">
                  <div class="text-caption text-medium-emphasis mb-2">
                    Click a placeholder to copy. Use them inside the header / footer HTML.
                  </div>
                  <v-row dense>
                    <v-col v-for="p in placeholders" :key="p.token" cols="12" sm="6" md="4">
                      <v-card flat rounded="lg" class="snippet pa-2 d-flex align-center"
                              @click="copyToken(p.token)">
                        <v-icon size="18" color="indigo-darken-2" class="mr-2">{{ p.icon }}</v-icon>
                        <div class="min-width-0">
                          <div class="font-weight-medium text-body-2 font-monospace">{{ p.token }}</div>
                          <div class="text-caption text-medium-emphasis text-truncate">{{ p.label }}</div>
                        </div>
                      </v-card>
                    </v-col>
                  </v-row>
                </v-window-item>
              </v-window>
            </v-col>

            <!-- Live preview side -->
            <v-col v-if="form.advanced" cols="6" class="pa-4 preview-col">
              <div class="d-flex align-center mb-2">
                <v-icon size="18" color="indigo-darken-2" class="mr-1">mdi-eye</v-icon>
                <div class="text-subtitle-2 font-weight-bold">Live preview</div>
                <v-spacer />
                <v-btn size="x-small" variant="text" prepend-icon="mdi-printer"
                       @click="printTemplate(form, true)">Print</v-btn>
              </div>
              <div class="report-preview" v-html="renderPreview(form, true)" />
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-btn v-if="!form.advanced" variant="text" prepend-icon="mdi-eye" @click="openPreview(form, true)">
            Preview
          </v-btn>
          <v-spacer />
          <v-btn variant="text" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" :loading="saving"
                 prepend-icon="mdi-content-save-outline" @click="save">
            {{ form.id ? 'Update template' : 'Create template' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ────────── Preview dialog ────────── -->
    <v-dialog v-model="previewDialog" max-width="900" scrollable>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="indigo-lighten-5" size="40" class="mr-3">
            <v-icon color="indigo-darken-2">mdi-eye</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">Preview</div>
            <div class="text-h6 font-weight-bold">{{ previewTarget?.name || 'Template preview' }}</div>
          </div>
          <v-spacer />
          <v-btn icon variant="text" size="small" @click="previewDialog = false">
            <v-icon>mdi-close</v-icon>
          </v-btn>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <div class="report-preview" v-html="renderPreview(previewTarget, true)" />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="previewDialog = false">Close</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-printer"
                 @click="printTemplate(previewTarget, true)">Print sample</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ────────── Delete confirm ────────── -->
    <v-dialog v-model="deleteDialog" max-width="440" persistent>
      <v-card v-if="deleteTarget" rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="error-lighten-5" size="40" class="mr-3">
            <v-icon color="error">mdi-delete-alert</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">Confirm delete</div>
            <div class="text-h6 font-weight-bold">Delete template?</div>
          </div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          This will permanently remove <strong>{{ deleteTarget.name }}</strong>.
          Reports already printed are unaffected.
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="saving"
                 prepend-icon="mdi-delete" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" :timeout="2400">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted, watch, nextTick } from 'vue'

const { $api } = useNuxtApp()

// ── State ───────────────────────────────────────────────
const loading = ref(false)
const saving = ref(false)
const templates = ref([])
const labProfile = ref(null)

const tab = ref('cards')
const search = ref('')
const deptFilter = ref(null)
const statusFilter = ref('all')

const sectionPills = [
  { value: 'cards',   label: 'Templates', color: 'indigo',        icon: 'mdi-view-grid' },
  { value: 'table',   label: 'Table',     color: 'teal',          icon: 'mdi-table' },
  { value: 'default', label: 'Default',   color: 'amber-darken-2', icon: 'mdi-star' },
]

const statusItems = [
  { title: 'All',      value: 'all' },
  { title: 'Active',   value: 'active' },
  { title: 'Inactive', value: 'inactive' },
  { title: 'Default',  value: 'default' },
]

const departmentSuggestions = [
  'Hematology', 'Clinical Chemistry', 'Microbiology', 'Histopathology',
  'Immunology', 'Molecular Biology', 'Blood Bank', 'Radiology', 'General',
]

// Common ready-made template names paired with a sensible department
const TEMPLATE_NAME_PRESETS = [
  { name: 'Standard Hematology Report',     department: 'Hematology' },
  { name: 'Complete Blood Count (CBC)',     department: 'Hematology' },
  { name: 'Coagulation Profile',            department: 'Hematology' },
  { name: 'Liver Function Tests',           department: 'Clinical Chemistry' },
  { name: 'Renal Function Tests',           department: 'Clinical Chemistry' },
  { name: 'Lipid Profile',                  department: 'Clinical Chemistry' },
  { name: 'Thyroid Function Tests',         department: 'Clinical Chemistry' },
  { name: 'Diabetes Panel (HbA1c · FBS)',   department: 'Clinical Chemistry' },
  { name: 'Electrolytes & Urea',            department: 'Clinical Chemistry' },
  { name: 'Urinalysis Report',              department: 'Microbiology' },
  { name: 'Stool Analysis',                 department: 'Microbiology' },
  { name: 'Culture & Sensitivity',          department: 'Microbiology' },
  { name: 'Malaria / Parasitology Report',  department: 'Microbiology' },
  { name: 'HIV / Viral Markers Report',     department: 'Immunology' },
  { name: 'Hepatitis Panel',                department: 'Immunology' },
  { name: 'Hormone Assay Report',           department: 'Immunology' },
  { name: 'Histopathology Report',          department: 'Histopathology' },
  { name: 'Cytology Report',                department: 'Histopathology' },
  { name: 'Blood Bank / Cross-match Report', department: 'Blood Bank' },
  { name: 'PCR / Molecular Test Report',    department: 'Molecular Biology' },
  { name: 'COVID-19 PCR Report',            department: 'Molecular Biology' },
  { name: 'Radiology / Imaging Report',     department: 'Radiology' },
  { name: 'Pre-employment / Medical Check-up', department: 'General' },
  { name: 'General Lab Report',             department: 'General' },
]
const templateNameSuggestions = TEMPLATE_NAME_PRESETS.map(p => p.name)
const quickTemplateNames = TEMPLATE_NAME_PRESETS.slice(0, 6)

function applyNamePreset(preset) {
  form.name = preset.name
  if (!form.department) form.department = preset.department
}
function onTemplateNamePicked(value) {
  if (!value) return
  const match = TEMPLATE_NAME_PRESETS.find(p => p.name === value)
  if (match && !form.department) form.department = match.department
}

const tableHeaders = [
  { title: 'Template',   key: 'name' },
  { title: 'Department', key: 'department', width: 160 },
  { title: 'Signatory',  key: 'signatory_name' },
  { title: 'Signature',  key: 'signature', sortable: false, align: 'center', width: 100 },
  { title: 'Active',     key: 'is_active', sortable: false, align: 'center', width: 100 },
  { title: '',           key: 'actions',   sortable: false, align: 'end',    width: 200 },
]

// ── Data loading ────────────────────────────────────────
async function loadAll() {
  loading.value = true
  try {
    const [{ data: tpls }, profileRes] = await Promise.all([
      $api.get('/lab/report-templates/', { params: { page_size: 200 } }),
      $api.get('/pharmacy-profile/profile/', { params: { page_size: 1 } }).catch(() => null),
    ])
    templates.value = tpls?.results || tpls || []
    const profileList = profileRes?.data?.results || profileRes?.data || []
    labProfile.value = Array.isArray(profileList) ? profileList[0] : profileList
  } catch (e) {
    notify(extractError(e) || 'Failed to load templates', 'error')
  } finally { loading.value = false }
}
onMounted(loadAll)

// ── Filtering ───────────────────────────────────────────
const deptItems = computed(() => {
  const set = new Set([...departmentSuggestions])
  templates.value.forEach(t => t.department && set.add(t.department))
  return [...set].sort((a, b) => a.localeCompare(b))
})

const filtered = computed(() => {
  const q = search.value.toLowerCase().trim()
  return templates.value.filter(t => {
    if (statusFilter.value === 'active'   && !t.is_active) return false
    if (statusFilter.value === 'inactive' &&  t.is_active) return false
    if (statusFilter.value === 'default'  && !t.is_default) return false
    if (deptFilter.value && t.department !== deptFilter.value) return false
    if (!q) return true
    return [t.name, t.department, t.signatory_name, t.signatory_title]
      .some(v => (v || '').toString().toLowerCase().includes(q))
  })
})

const defaultTemplate = computed(() => templates.value.find(t => t.is_default) || null)

const kpiTiles = computed(() => {
  const total = templates.value.length
  const active = templates.value.filter(t => t.is_active).length
  const withSig = templates.value.filter(t => t.signatory_signature).length
  return [
    { label: 'Total templates',    value: total,          icon: 'mdi-file-document-multiple', color: 'indigo',         filter: 'all' },
    { label: 'Active',             value: active,         icon: 'mdi-check-circle',           color: 'green',          sub: `${total - active} inactive`, filter: 'active' },
    { label: 'Default',            value: defaultTemplate.value ? 1 : 0,
      sub: defaultTemplate.value?.name || 'Not set',
      icon: 'mdi-star',                  color: 'amber',          filter: 'default' },
    { label: 'With signature',     value: withSig,        icon: 'mdi-draw',                   color: 'deep-purple',    sub: `${total - withSig} missing` },
  ]
})

const hasOtherDefault = computed(() =>
  templates.value.some(t => t.is_default && t.id !== form.id),
)

// ── Form / dialog ───────────────────────────────────────
const formDialog = ref(false)
const formTab = ref('basic')
const form = reactive(blankForm())
const errors = reactive({})
const signatureFile = ref(null)
const signaturePreview = ref('')

// Signature mode + drawing pad + typed signature
const signatureMode = ref('upload')
const padCanvas = ref(null)
const padStrokes = ref([])     // [[ {x,y,color,width}, ... ], ...]
let   padCurrent = null
const padEmpty = ref(true)
const penColor = ref('#1e3a8a')
const penWidth = ref(2.5)
const penColors = ['#1e3a8a', '#000000', '#0d47a1', '#1b5e20', '#b71c1c']
const typedSignature = ref('')
const typedFont = ref('"Dancing Script", "Brush Script MT", cursive')
const signatureFonts = [
  { title: 'Cursive (Dancing Script)', value: '"Dancing Script", "Brush Script MT", cursive' },
  { title: 'Brush Script',             value: '"Brush Script MT", "Lucida Handwriting", cursive' },
  { title: 'Italic Serif',             value: '"Times New Roman", Times, serif' },
  { title: 'Handwriting (Caveat)',     value: '"Caveat", "Segoe Script", cursive' },
  { title: 'Bold Sans',                value: '"Segoe UI", Arial, sans-serif' },
]

watch(signatureMode, async (m) => {
  if (m === 'draw') { await nextTick(); setupPad() }
  if (m === 'type') renderTypedSignature()
})

function blankForm() {
  return {
    id: null, name: '', department: '',
    header_html: defaultHeaderHtml(),
    footer_html: defaultFooterHtml(),
    signatory_name: '', signatory_title: '',
    signatory_signature: null, signatory_signature_url: '',
    is_default: false, is_active: true,
    advanced: true,
  }
}
function clearErrors() { Object.keys(errors).forEach(k => delete errors[k]) }
function clearSignature() {
  signatureFile.value = null
  signaturePreview.value = ''
  form.signatory_signature = ''  // empty string tells DRF to clear
  form.signatory_signature_url = ''
  padStrokes.value = []
  typedSignature.value = ''
  if (signatureMode.value === 'draw') redrawPad()
}
function onSignaturePicked(file) {
  const f = Array.isArray(file) ? file[0] : file
  if (!f) { signaturePreview.value = ''; return }
  const reader = new FileReader()
  reader.onload = (e) => { signaturePreview.value = e.target.result }
  reader.readAsDataURL(f)
}

// ── Signature pad (draw mode) ─────────────────────────
function setupPad() {
  const cnv = padCanvas.value
  if (!cnv) return
  const dpr = window.devicePixelRatio || 1
  const rect = cnv.getBoundingClientRect()
  cnv.width = Math.round(rect.width * dpr)
  cnv.height = Math.round(rect.height * dpr)
  const ctx = cnv.getContext('2d')
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
  ctx.lineCap = 'round'
  ctx.lineJoin = 'round'
  redrawPad()
}
function redrawPad() {
  const cnv = padCanvas.value
  if (!cnv) return
  const ctx = cnv.getContext('2d')
  const dpr = window.devicePixelRatio || 1
  ctx.clearRect(0, 0, cnv.width / dpr, cnv.height / dpr)
  for (const stroke of padStrokes.value) {
    if (!stroke.length) continue
    ctx.strokeStyle = stroke[0].color
    ctx.lineWidth = stroke[0].width
    ctx.beginPath()
    ctx.moveTo(stroke[0].x, stroke[0].y)
    for (let i = 1; i < stroke.length; i++) ctx.lineTo(stroke[i].x, stroke[i].y)
    ctx.stroke()
  }
  padEmpty.value = padStrokes.value.length === 0
}
function padPoint(e) {
  const rect = padCanvas.value.getBoundingClientRect()
  return { x: e.clientX - rect.left, y: e.clientY - rect.top, color: penColor.value, width: penWidth.value }
}
function padStart(e) {
  e.preventDefault()
  padCanvas.value.setPointerCapture?.(e.pointerId)
  padCurrent = [padPoint(e)]
  padStrokes.value.push(padCurrent)
}
function padMove(e) {
  if (!padCurrent) return
  padCurrent.push(padPoint(e))
  redrawPad()
}
function padEnd() { padCurrent = null }
function padUndo() { padStrokes.value.pop(); redrawPad() }
function padClear() { padStrokes.value = []; redrawPad() }
function padCommit() {
  const cnv = padCanvas.value
  if (!cnv || padEmpty.value) return
  // Trim to visible bounds for a tighter image
  const dpr = window.devicePixelRatio || 1
  const trimmed = trimCanvas(cnv, dpr)
  trimmed.toBlob((blob) => {
    if (!blob) return
    const file = new File([blob], 'signature-drawn.png', { type: 'image/png' })
    signatureFile.value = file
    signaturePreview.value = trimmed.toDataURL('image/png')
    form.signatory_signature_url = ''
    notify('Drawn signature ready', 'success')
  }, 'image/png')
}
function trimCanvas(src, dpr) {
  const ctx = src.getContext('2d')
  const w = src.width, h = src.height
  const data = ctx.getImageData(0, 0, w, h).data
  let top = h, left = w, right = 0, bottom = 0, found = false
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (data[(y * w + x) * 4 + 3] !== 0) {
        found = true
        if (y < top) top = y
        if (y > bottom) bottom = y
        if (x < left) left = x
        if (x > right) right = x
      }
    }
  }
  if (!found) return src
  const pad = 6 * dpr
  top = Math.max(0, top - pad); left = Math.max(0, left - pad)
  bottom = Math.min(h - 1, bottom + pad); right = Math.min(w - 1, right + pad)
  const cw = right - left + 1, ch = bottom - top + 1
  const out = document.createElement('canvas')
  out.width = cw; out.height = ch
  out.getContext('2d').drawImage(src, left, top, cw, ch, 0, 0, cw, ch)
  return out
}

// ── Typed signature (type mode) ───────────────────────
function renderTypedSignature() {
  if (!typedSignature.value.trim()) { return }
  const text = typedSignature.value
  const cnv = document.createElement('canvas')
  const scale = 2
  const fontPx = 56
  cnv.width = 720 * scale
  cnv.height = 140 * scale
  const ctx = cnv.getContext('2d')
  ctx.scale(scale, scale)
  ctx.fillStyle = penColor.value
  ctx.font = `italic ${fontPx}px ${typedFont.value}`
  ctx.textBaseline = 'middle'
  const metrics = ctx.measureText(text)
  const w = Math.min(720, Math.ceil(metrics.width) + 40)
  const out = document.createElement('canvas')
  out.width = w * scale; out.height = 140 * scale
  const octx = out.getContext('2d')
  octx.scale(scale, scale)
  octx.fillStyle = penColor.value
  octx.font = `italic ${fontPx}px ${typedFont.value}`
  octx.textBaseline = 'middle'
  octx.fillText(text, 20, 70)
  signaturePreview.value = out.toDataURL('image/png')
}
function commitTypedSignature() {
  if (!typedSignature.value.trim()) return
  renderTypedSignature()
  const data = signaturePreview.value
  fetch(data).then(r => r.blob()).then(blob => {
    signatureFile.value = new File([blob], 'signature-typed.png', { type: 'image/png' })
    form.signatory_signature_url = ''
    notify('Typed signature ready', 'success')
  })
}

function openCreate() {
  Object.assign(form, blankForm())
  if (!templates.value.length) form.is_default = true
  clearErrors(); signatureFile.value = null; signaturePreview.value = ''
  formTab.value = 'basic'; formDialog.value = true
}
function openEdit(t) {
  Object.assign(form, blankForm(), {
    ...t,
    signatory_signature_url: t.signatory_signature || '',
    signatory_signature: null,
    advanced: form.advanced,
  })
  clearErrors(); signatureFile.value = null; signaturePreview.value = ''
  formTab.value = 'basic'; formDialog.value = true
}

function duplicate(t) {
  Object.assign(form, blankForm(), {
    ...t, id: null,
    name: `${t.name} (copy)`,
    is_default: false,
    signatory_signature_url: t.signatory_signature || '',
    signatory_signature: null,
  })
  clearErrors(); signatureFile.value = null; signaturePreview.value = ''
  formTab.value = 'basic'; formDialog.value = true
  notify('Template duplicated — review and save', 'info')
}

async function save() {
  clearErrors()
  if (!form.name?.trim()) {
    errors.name = 'Template name is required'
    formTab.value = 'basic'
    return
  }
  saving.value = true
  try {
    let payload, headers
    if (signatureFile.value || form.signatory_signature === '') {
      // Send multipart so we can upload a new image (or clear it)
      payload = new FormData()
      payload.append('name', form.name)
      payload.append('department', form.department || '')
      payload.append('header_html', form.header_html || '')
      payload.append('footer_html', form.footer_html || '')
      payload.append('signatory_name', form.signatory_name || '')
      payload.append('signatory_title', form.signatory_title || '')
      payload.append('is_default', form.is_default ? 'true' : 'false')
      payload.append('is_active', form.is_active ? 'true' : 'false')
      if (signatureFile.value) {
        const f = Array.isArray(signatureFile.value) ? signatureFile.value[0] : signatureFile.value
        if (f) payload.append('signatory_signature', f)
      } else if (form.signatory_signature === '') {
        payload.append('signatory_signature', '')
      }
      headers = { 'Content-Type': 'multipart/form-data' }
    } else {
      payload = {
        name: form.name,
        department: form.department || '',
        header_html: form.header_html || '',
        footer_html: form.footer_html || '',
        signatory_name: form.signatory_name || '',
        signatory_title: form.signatory_title || '',
        is_default: form.is_default,
        is_active: form.is_active,
      }
    }
    if (form.id) {
      await $api.patch(`/lab/report-templates/${form.id}/`, payload, headers ? { headers } : undefined)
    } else {
      await $api.post('/lab/report-templates/', payload, headers ? { headers } : undefined)
    }
    // If marked default, unset previous defaults to keep a single default.
    if (form.is_default) await unsetOtherDefaults(form.id)
    notify(form.id ? 'Template updated' : 'Template created', 'success')
    formDialog.value = false
    await loadAll()
  } catch (e) {
    notify(extractError(e) || 'Save failed', 'error')
  } finally { saving.value = false }
}

async function unsetOtherDefaults(keepId) {
  const others = templates.value.filter(t => t.is_default && t.id !== keepId)
  if (!others.length) return
  await Promise.all(others.map(t =>
    $api.patch(`/lab/report-templates/${t.id}/`, { is_default: false }),
  ))
}

// ── Quick actions ───────────────────────────────────────
async function toggleActive(item, value) {
  try {
    await $api.patch(`/lab/report-templates/${item.id}/`, { is_active: value })
    item.is_active = value
    notify(value ? 'Template activated' : 'Template deactivated', 'success')
  } catch (e) { notify(extractError(e) || 'Update failed', 'error') }
}
async function setDefault(item) {
  if (item.is_default) return
  try {
    await unsetOtherDefaults(item.id)
    await $api.patch(`/lab/report-templates/${item.id}/`, { is_default: true })
    notify(`${item.name} is now the default`, 'success')
    await loadAll()
  } catch (e) { notify(extractError(e) || 'Could not set default', 'error') }
}

// ── Delete ──────────────────────────────────────────────
const deleteDialog = ref(false)
const deleteTarget = ref(null)
function confirmDelete(t) { deleteTarget.value = t; deleteDialog.value = true }
async function doDelete() {
  saving.value = true
  try {
    await $api.delete(`/lab/report-templates/${deleteTarget.value.id}/`)
    notify('Template deleted', 'success')
    deleteDialog.value = false
    await loadAll()
  } catch (e) { notify(extractError(e) || 'Delete failed', 'error') }
  finally { saving.value = false }
}

// ── Preview ─────────────────────────────────────────────
const previewDialog = ref(false)
const previewTarget = ref(null)
function openPreview(t) {
  previewTarget.value = t
  previewDialog.value = true
}

const placeholders = [
  { token: '{{lab_name}}',      label: 'Lab / clinic name',     icon: 'mdi-bank' },
  { token: '{{lab_logo}}',      label: 'Lab logo (image URL)',  icon: 'mdi-image' },
  { token: '{{lab_address}}',   label: 'Lab postal address',    icon: 'mdi-map-marker' },
  { token: '{{lab_phone}}',     label: 'Lab phone',             icon: 'mdi-phone' },
  { token: '{{lab_email}}',     label: 'Lab email',             icon: 'mdi-email' },
  { token: '{{license_no}}',    label: 'Lab license number',    icon: 'mdi-certificate' },
  { token: '{{patient_name}}',  label: 'Patient name',          icon: 'mdi-account' },
  { token: '{{patient_id}}',    label: 'Patient ID / MRN',      icon: 'mdi-card-account-details' },
  { token: '{{age_sex}}',       label: 'Age / sex',             icon: 'mdi-account-details' },
  { token: '{{order_no}}',      label: 'Order / requisition #', icon: 'mdi-barcode' },
  { token: '{{accession_no}}',  label: 'Accession number',      icon: 'mdi-barcode-scan' },
  { token: '{{collected_at}}',  label: 'Specimen collection',   icon: 'mdi-test-tube' },
  { token: '{{reported_at}}',   label: 'Report date / time',    icon: 'mdi-calendar-clock' },
  { token: '{{referring_dr}}',  label: 'Referring doctor',      icon: 'mdi-doctor' },
  { token: '{{report_title}}',  label: 'Report title',          icon: 'mdi-file-document' },
  { token: '{{page_number}}',   label: 'Page number',           icon: 'mdi-numeric' },
  { token: '{{signatory_name}}',label: 'Signatory name',        icon: 'mdi-account-tie' },
  { token: '{{signatory_title}}', label: 'Signatory title',     icon: 'mdi-certificate' },
]

function copyToken(token) {
  if (navigator.clipboard) {
    navigator.clipboard.writeText(token)
      .then(() => notify(`Copied ${token}`, 'info'))
      .catch(() => notify('Copy failed', 'warning'))
  }
}

const SAMPLE = {
  patient_name: 'Jane M. Wanjiku',
  patient_id: 'MRN-00284',
  age_sex: '34 yrs · Female',
  order_no: 'REQ-00187',
  accession_no: 'A260512-0042',
  collected_at: 'May 12, 2026 · 08:42',
  reported_at: 'May 12, 2026 · 11:15',
  referring_dr: 'Dr. Otieno (Nairobi GP)',
  report_title: 'Complete Blood Count',
  page_number: '1 of 1',
}

function fillPlaceholders(html, t) {
  if (!html) return ''
  const lab = labProfile.value || {}
  const sigUrl = signaturePreview.value || t?.signatory_signature_url || t?.signatory_signature || ''
  const map = {
    '{{lab_name}}':      lab.name || 'Your Lab Name',
    '{{lab_logo}}':      lab.logo_url
      ? `<img src="${lab.logo_url}" style="max-height:54px" />`
      : '<span style="color:#999;font-style:italic">[lab logo]</span>',
    '{{lab_address}}':   lab.address || 'P.O. Box 12345, Nairobi',
    '{{lab_phone}}':     lab.phone || '+254 700 000000',
    '{{lab_email}}':     lab.email || 'info@yourlab.co.ke',
    '{{license_no}}':    lab.license_number || 'LIC-XXXXX',
    '{{signatory_name}}': t?.signatory_name || 'Dr. Authorised Signatory',
    '{{signatory_title}}': t?.signatory_title || 'Lab Director',
    '{{signature_image}}': sigUrl
      ? `<img src="${sigUrl}" style="max-height:48px" />`
      : '<span style="color:#bbb">[signature]</span>',
    ...Object.fromEntries(Object.entries(SAMPLE).map(([k, v]) => [`{{${k}}}`, v])),
  }
  let out = html
  for (const [k, v] of Object.entries(map)) out = out.split(k).join(v)
  return out
}

function renderPreview(t, full = false) {
  if (!t) return ''
  const header = fillPlaceholders(t.header_html, t)
  const footer = fillPlaceholders(t.footer_html, t)
  const sigUrl = signaturePreview.value || t?.signatory_signature_url || t?.signatory_signature || ''
  const body = full ? sampleBody() : ''
  return `
    <div class="rp-page">
      <div class="rp-header">${header || '<div class="rp-empty">No header</div>'}</div>
      ${body}
      <div class="rp-sign">
        <div class="rp-sign-line">
          ${sigUrl ? `<img src="${sigUrl}" />` : ''}
        </div>
        <div class="rp-sign-name">${t.signatory_name || ''}</div>
        <div class="rp-sign-title">${t.signatory_title || ''}</div>
      </div>
      <div class="rp-footer">${footer || '<div class="rp-empty">No footer</div>'}</div>
    </div>`
}

function sampleBody() {
  return `
    <div class="rp-meta">
      <div><strong>Patient:</strong> ${SAMPLE.patient_name} <span class="rp-muted">(${SAMPLE.patient_id})</span></div>
      <div><strong>Age / Sex:</strong> ${SAMPLE.age_sex}</div>
      <div><strong>Order #:</strong> ${SAMPLE.order_no} · <strong>Accession:</strong> ${SAMPLE.accession_no}</div>
      <div><strong>Collected:</strong> ${SAMPLE.collected_at} · <strong>Reported:</strong> ${SAMPLE.reported_at}</div>
      <div><strong>Referring:</strong> ${SAMPLE.referring_dr}</div>
    </div>
    <h3 class="rp-title">${SAMPLE.report_title}</h3>
    <table class="rp-table">
      <thead><tr><th>Parameter</th><th>Result</th><th>Unit</th><th>Reference</th><th>Flag</th></tr></thead>
      <tbody>
        <tr><td>Hemoglobin</td><td>13.4</td><td>g/dL</td><td>12.0 – 15.5</td><td></td></tr>
        <tr><td>WBC</td><td>11.8</td><td>×10⁹/L</td><td>4.0 – 10.0</td><td><b style="color:#c0392b">H</b></td></tr>
        <tr><td>Platelets</td><td>248</td><td>×10⁹/L</td><td>150 – 400</td><td></td></tr>
        <tr><td>RBC</td><td>4.62</td><td>×10¹²/L</td><td>4.20 – 5.40</td><td></td></tr>
        <tr><td>Hematocrit</td><td>40.1</td><td>%</td><td>36 – 46</td><td></td></tr>
      </tbody>
    </table>`
}

function thumbHtml(t) {
  const header = fillPlaceholders(t.header_html, t)
  const footer = fillPlaceholders(t.footer_html, t)
  return `
    <div class="rp-thumb">
      <div class="rp-thumb-h">${header || '<span class="rp-muted">No header</span>'}</div>
      <div class="rp-thumb-body"></div>
      <div class="rp-thumb-f">${footer || '<span class="rp-muted">No footer</span>'}</div>
    </div>`
}

function printTemplate(t, useFormState = false) {
  const target = useFormState ? form : t
  if (!target) return
  const html = renderPreview(target, true)
  const w = window.open('', '_blank', 'noopener,noreferrer,width=900,height=1100')
  if (!w) { notify('Popup blocked — allow popups to print', 'warning'); return }
  w.document.write(`<!doctype html><html><head><title>${target.name || 'Report preview'}</title>
<style>
  body { font-family: 'Segoe UI', Arial, sans-serif; color: #222; margin: 0; padding: 24px; }
  .rp-page { max-width: 760px; margin: 0 auto; }
  .rp-header, .rp-footer { padding: 12px 0; }
  .rp-header { border-bottom: 2px solid #1e3a8a; margin-bottom: 16px; }
  .rp-footer { border-top: 1px solid #ddd; margin-top: 24px; font-size: 11px; color: #666; }
  .rp-meta { font-size: 12px; line-height: 1.6; margin-bottom: 12px; }
  .rp-meta .rp-muted { color: #888; }
  .rp-title { font-size: 16px; margin: 12px 0 8px; color: #1e3a8a; border-bottom: 1px solid #eee; padding-bottom: 4px; }
  .rp-table { width: 100%; border-collapse: collapse; font-size: 12px; }
  .rp-table th, .rp-table td { border: 1px solid #e0e0e0; padding: 6px 8px; text-align: left; }
  .rp-table th { background: #f5f7ff; }
  .rp-sign { margin-top: 32px; text-align: right; }
  .rp-sign-line { border-bottom: 1px solid #444; min-height: 50px; min-width: 240px; display: inline-block; }
  .rp-sign-line img { max-height: 48px; vertical-align: bottom; }
  .rp-sign-name { font-weight: 600; margin-top: 4px; }
  .rp-sign-title { font-size: 11px; color: #666; }
  .rp-empty { color: #bbb; font-style: italic; }
</style></head><body>${html}<script>window.onload=()=>setTimeout(()=>window.print(),250)<\/script></body></html>`)
  w.document.close()
}

// ── Presets ─────────────────────────────────────────────
function defaultHeaderHtml() {
  return `<div style="display:flex;align-items:center;gap:12px">
  <div>{{lab_logo}}</div>
  <div style="flex:1">
    <div style="font-size:18px;font-weight:700;color:#1e3a8a">{{lab_name}}</div>
    <div style="font-size:11px;color:#666">{{lab_address}} · {{lab_phone}} · {{lab_email}}</div>
    <div style="font-size:10px;color:#999">License: {{license_no}}</div>
  </div>
  <div style="text-align:right;font-size:10px;color:#666">
    <div>Report: <b>{{report_title}}</b></div>
    <div>Date: {{reported_at}}</div>
  </div>
</div>`
}
function defaultFooterHtml() {
  return `<div style="display:flex;justify-content:space-between;font-size:10px;color:#888">
  <div>This report is electronically generated. Verified by {{signatory_name}}.</div>
  <div>Page {{page_number}}</div>
</div>`
}
function loadHeaderPreset(kind) {
  if (kind === 'logo') form.header_html = defaultHeaderHtml()
  else if (kind === 'minimal') {
    form.header_html = `<div style="text-align:center">
  <div style="font-size:20px;font-weight:700">{{lab_name}}</div>
  <div style="font-size:11px;color:#666">{{lab_address}} · {{lab_phone}}</div>
</div>`
  } else if (kind === 'banded') {
    form.header_html = `<div style="background:#1e3a8a;color:#fff;padding:12px 16px;border-radius:6px;display:flex;align-items:center;gap:12px">
  <div>{{lab_logo}}</div>
  <div style="flex:1">
    <div style="font-size:18px;font-weight:700">{{lab_name}}</div>
    <div style="font-size:11px;opacity:0.9">{{lab_address}} · {{lab_phone}}</div>
  </div>
  <div style="font-size:11px;text-align:right;opacity:0.9">{{report_title}}<br>{{reported_at}}</div>
</div>`
  }
}
function loadFooterPreset(kind) {
  if (kind === 'contact') {
    form.footer_html = `<div style="text-align:center;font-size:10px;color:#666">
  {{lab_name}} · {{lab_address}} · {{lab_phone}} · {{lab_email}}
</div>`
  } else if (kind === 'disclaimer') {
    form.footer_html = `<div style="font-size:10px;color:#888;text-align:justify">
  This report relates only to the specimen received. Results should be interpreted in conjunction with clinical findings and other diagnostic information.
  Reference ranges may vary with age, sex and method.
</div>`
  } else if (kind === 'page') {
    form.footer_html = defaultFooterHtml()
  }
}

// ── Export ──────────────────────────────────────────────
function exportCsv() {
  const rows = filtered.value
  if (!rows.length) { notify('Nothing to export', 'warning'); return }
  const headers = ['Name', 'Department', 'Signatory', 'Signatory Title', 'Has signature', 'Default', 'Active', 'Created']
  const csv = [headers.join(',')]
  for (const t of rows) {
    csv.push([
      t.name, t.department || '', t.signatory_name || '', t.signatory_title || '',
      t.signatory_signature ? 'Yes' : 'No',
      t.is_default ? 'Yes' : 'No', t.is_active ? 'Yes' : 'No',
      t.created_at || '',
    ].map(v => `"${String(v).replace(/"/g, '""')}"`).join(','))
  }
  const blob = new Blob([csv.join('\n')], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = `lab-report-templates-${new Date().toISOString().slice(0, 10)}.csv`
  a.click(); URL.revokeObjectURL(url)
}

// ── Misc helpers ────────────────────────────────────────
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
.section-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.section-pills { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.notes-card {
  background: rgba(var(--v-theme-warning), 0.06);
  border: 1px solid rgba(var(--v-theme-warning), 0.2);
}
.tpl-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.tpl-card:hover { transform: translateY(-2px); box-shadow: 0 8px 22px rgba(0, 0, 0, 0.08); }
.tpl-card.is-default { border-color: rgba(var(--v-theme-warning), 0.4); }
.tpl-card.is-inactive { opacity: 0.7; }

.snippet {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: background 0.15s ease, border-color 0.15s ease;
}
.snippet:hover { background: rgba(var(--v-theme-indigo), 0.04); border-color: rgba(var(--v-theme-indigo), 0.4); }

.signature-preview {
  border: 1px dashed rgba(0, 0, 0, 0.15);
  border-radius: 8px;
  padding: 8px 12px;
  background: #fff;
}
.signature-preview img { max-height: 64px; max-width: 220px; display: block; }

.signature-pad-wrap {
  position: relative;
  border: 1px dashed rgba(var(--v-theme-indigo), 0.4);
  border-radius: 8px;
  background:
    linear-gradient(#fff, #fff),
    repeating-linear-gradient(transparent, transparent 39px, rgba(0, 0, 0, 0.05) 40px);
  background-clip: padding-box;
  height: 180px;
  overflow: hidden;
}
.signature-pad {
  width: 100%;
  height: 100%;
  display: block;
  cursor: crosshair;
  touch-action: none;
}
.signature-pad-hint {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  pointer-events: none;
  color: rgba(0, 0, 0, 0.3);
  font-size: 13px;
  font-style: italic;
}
.pen-swatch {
  display: inline-block;
  width: 16px; height: 16px;
  border-radius: 50%;
  border: 2px solid #fff;
  box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.2);
}
.signature-typed-preview {
  border: 1px dashed rgba(0, 0, 0, 0.15);
  border-radius: 8px;
  padding: 14px 18px;
  background: #fff;
  font-size: 36px;
  line-height: 1.2;
  min-height: 70px;
  display: flex;
  align-items: center;
}

.preview-col {
  background: rgba(0, 0, 0, 0.02);
  border-left: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}

.report-preview {
  background: #fff;
  border: 1px solid rgba(0, 0, 0, 0.08);
  border-radius: 8px;
  padding: 18px 22px;
  font-family: 'Segoe UI', Arial, sans-serif;
  color: #222;
  font-size: 13px;
  min-height: 320px;
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0.04);
}
.report-preview :deep(.rp-header) { border-bottom: 2px solid #1e3a8a; padding-bottom: 10px; margin-bottom: 14px; }
.report-preview :deep(.rp-footer) { border-top: 1px solid #ddd; padding-top: 8px; margin-top: 24px; font-size: 11px; color: #666; }
.report-preview :deep(.rp-empty) { color: #bbb; font-style: italic; font-size: 11px; }
.report-preview :deep(.rp-meta) { font-size: 12px; line-height: 1.6; margin-bottom: 12px; color: #333; }
.report-preview :deep(.rp-meta .rp-muted) { color: #888; }
.report-preview :deep(.rp-title) { font-size: 15px; margin: 12px 0 8px; color: #1e3a8a; border-bottom: 1px solid #eee; padding-bottom: 4px; }
.report-preview :deep(.rp-table) { width: 100%; border-collapse: collapse; font-size: 12px; }
.report-preview :deep(.rp-table th),
.report-preview :deep(.rp-table td) { border: 1px solid #e0e0e0; padding: 5px 8px; text-align: left; }
.report-preview :deep(.rp-table th) { background: #f5f7ff; color: #1e3a8a; }
.report-preview :deep(.rp-sign) { margin-top: 24px; text-align: right; }
.report-preview :deep(.rp-sign-line) { border-bottom: 1px solid #444; min-height: 44px; min-width: 220px; display: inline-block; }
.report-preview :deep(.rp-sign-line img) { max-height: 40px; vertical-align: bottom; }
.report-preview :deep(.rp-sign-name) { font-weight: 600; margin-top: 4px; }
.report-preview :deep(.rp-sign-title) { font-size: 11px; color: #666; }

.tpl-thumb {
  background: #fafafa;
  border: 1px solid rgba(0, 0, 0, 0.06);
  border-radius: 6px;
  height: 90px;
  overflow: hidden;
  position: relative;
  font-size: 9px;
  color: #555;
}
.tpl-thumb :deep(.rp-thumb) { padding: 4px 6px; }
.tpl-thumb :deep(.rp-thumb-h) { border-bottom: 1px solid #ccc; padding-bottom: 2px; max-height: 28px; overflow: hidden; }
.tpl-thumb :deep(.rp-thumb-body) { height: 22px; background: repeating-linear-gradient(transparent, transparent 4px, #eee 4px, #eee 5px); margin: 4px 0; }
.tpl-thumb :deep(.rp-thumb-f) { border-top: 1px solid #eee; padding-top: 2px; max-height: 18px; overflow: hidden; font-size: 8px; }
.tpl-thumb :deep(.rp-muted) { color: #bbb; font-style: italic; }
.tpl-thumb :deep(img) { max-height: 18px; }

.mono-input :deep(textarea) {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 12px;
  line-height: 1.5;
}
.editor-window { padding-top: 20px; }
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
.acct-table :deep(tbody tr:hover) { background: #eef2ff !important; }
</style>
