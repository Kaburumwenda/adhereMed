<template>
  <div class="rte" :class="{ 'rte--focused': focused }">
    <div class="rte__toolbar">
      <v-btn-toggle density="compact" variant="text" color="teal-darken-2" class="rte__group" divided>
        <v-btn size="small" icon @mousedown.prevent="wrap('**', '**', 'bold text')" title="Bold">
          <v-icon icon="mdi-format-bold" />
        </v-btn>
        <v-btn size="small" icon @mousedown.prevent="wrap('*', '*', 'italic text')" title="Italic">
          <v-icon icon="mdi-format-italic" />
        </v-btn>
        <v-btn size="small" icon @mousedown.prevent="wrap('~~', '~~', 'strikethrough')" title="Strikethrough">
          <v-icon icon="mdi-format-strikethrough" />
        </v-btn>
        <v-btn size="small" icon @mousedown.prevent="wrap('`', '`', 'code')" title="Inline code">
          <v-icon icon="mdi-code-tags" />
        </v-btn>
      </v-btn-toggle>

      <v-divider vertical class="mx-1" />

      <v-btn-toggle density="compact" variant="text" color="teal-darken-2" class="rte__group" divided>
        <v-btn size="small" icon @mousedown.prevent="prefixLines('# ')" title="Heading 1">
          <v-icon icon="mdi-format-header-1" />
        </v-btn>
        <v-btn size="small" icon @mousedown.prevent="prefixLines('## ')" title="Heading 2">
          <v-icon icon="mdi-format-header-2" />
        </v-btn>
        <v-btn size="small" icon @mousedown.prevent="prefixLines('### ')" title="Heading 3">
          <v-icon icon="mdi-format-header-3" />
        </v-btn>
        <v-btn size="small" icon @mousedown.prevent="prefixLines('> ')" title="Quote">
          <v-icon icon="mdi-format-quote-close" />
        </v-btn>
      </v-btn-toggle>

      <v-divider vertical class="mx-1" />

      <v-btn-toggle density="compact" variant="text" color="teal-darken-2" class="rte__group" divided>
        <v-btn size="small" icon @mousedown.prevent="prefixLines('- ')" title="Bullet list">
          <v-icon icon="mdi-format-list-bulleted" />
        </v-btn>
        <v-btn size="small" icon @mousedown.prevent="numberedList()" title="Numbered list">
          <v-icon icon="mdi-format-list-numbered" />
        </v-btn>
        <v-btn size="small" icon @mousedown.prevent="prefixLines('- [ ] ')" title="Checklist">
          <v-icon icon="mdi-format-list-checks" />
        </v-btn>
      </v-btn-toggle>

      <v-divider vertical class="mx-1" />

      <v-btn-toggle density="compact" variant="text" color="teal-darken-2" class="rte__group" divided>
        <v-btn size="small" icon @mousedown.prevent="addLink" title="Insert link">
          <v-icon icon="mdi-link-variant" />
        </v-btn>
        <v-btn size="small" icon @mousedown.prevent="insert('\n---\n')" title="Divider">
          <v-icon icon="mdi-minus" />
        </v-btn>
      </v-btn-toggle>

      <v-spacer />

      <v-btn-toggle v-model="mode" density="compact" variant="text" mandatory
                    color="teal-darken-2" class="rte__group" divided>
        <v-btn size="small" value="write" class="text-none">
          <v-icon icon="mdi-pencil-outline" start />Write
        </v-btn>
        <v-btn size="small" value="preview" class="text-none">
          <v-icon icon="mdi-eye-outline" start />Preview
        </v-btn>
      </v-btn-toggle>
    </div>

    <textarea
      v-show="mode === 'write'"
      ref="taEl"
      class="rte__textarea"
      :style="editorStyle"
      :placeholder="placeholder"
      :value="modelValue"
      @input="onInput"
      @focus="focused = true"
      @blur="focused = false"
      @keydown.tab.prevent="onTab"
    />

    <div
      v-if="mode === 'preview'"
      class="rte__preview"
      :style="editorStyle"
      v-html="previewHtml"
    />
  </div>
</template>

<script setup>
const props = defineProps({
  modelValue: { type: String, default: '' },
  placeholder: { type: String, default: 'Write your note… Markdown supported.' },
  minHeight: { type: [String, Number], default: 240 },
})
const emit = defineEmits(['update:modelValue'])

const taEl = ref(null)
const focused = ref(false)
const mode = ref('write')

const editorStyle = computed(() => ({
  minHeight: typeof props.minHeight === 'number' ? `${props.minHeight}px` : props.minHeight,
}))

function onInput(e) {
  emit('update:modelValue', e.target.value)
}

function getSel() {
  const ta = taEl.value
  if (!ta) return null
  return { start: ta.selectionStart, end: ta.selectionEnd, value: ta.value || '' }
}

async function setSel(start, end) {
  await nextTick()
  const ta = taEl.value
  if (!ta) return
  ta.focus()
  ta.setSelectionRange(start, end)
}

function commit(newValue, selStart, selEnd) {
  emit('update:modelValue', newValue)
  setSel(selStart, selEnd)
}

function wrap(before, after, placeholder = '') {
  const sel = getSel()
  if (!sel) return
  const { start, end, value } = sel
  const selected = value.slice(start, end) || placeholder
  const next = value.slice(0, start) + before + selected + after + value.slice(end)
  commit(next, start + before.length, start + before.length + selected.length)
}

function prefixLines(prefix) {
  const sel = getSel()
  if (!sel) return
  const { start, end, value } = sel
  const lineStart = value.lastIndexOf('\n', start - 1) + 1
  const lineEnd = end === start ? value.indexOf('\n', end) : end
  const safeEnd = lineEnd === -1 ? value.length : lineEnd
  const block = value.slice(lineStart, safeEnd)
  const lines = block.split('\n')
  const updated = lines.map(l => prefix + l).join('\n')
  const next = value.slice(0, lineStart) + updated + value.slice(safeEnd)
  commit(next, lineStart, lineStart + updated.length)
}

function numberedList() {
  const sel = getSel()
  if (!sel) return
  const { start, end, value } = sel
  const lineStart = value.lastIndexOf('\n', start - 1) + 1
  const lineEnd = end === start ? value.indexOf('\n', end) : end
  const safeEnd = lineEnd === -1 ? value.length : lineEnd
  const block = value.slice(lineStart, safeEnd)
  const lines = block.split('\n')
  const updated = lines.map((l, i) => `${i + 1}. ${l}`).join('\n')
  const next = value.slice(0, lineStart) + updated + value.slice(safeEnd)
  commit(next, lineStart, lineStart + updated.length)
}

function insert(text) {
  const sel = getSel()
  if (!sel) return
  const { start, end, value } = sel
  const next = value.slice(0, start) + text + value.slice(end)
  commit(next, start + text.length, start + text.length)
}

function addLink() {
  if (typeof window === 'undefined') return
  const url = window.prompt('Enter URL', 'https://')
  if (!url) return
  const sel = getSel()
  if (!sel) return
  const { start, end, value } = sel
  const text = value.slice(start, end) || 'link text'
  const md = `[${text}](${url})`
  const next = value.slice(0, start) + md + value.slice(end)
  commit(next, start + 1, start + 1 + text.length)
}

function onTab() {
  insert('  ')
}

// ── tiny safe markdown → HTML for preview ────────────────────────────
function escapeHtml(s) {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

function inline(s) {
  let t = escapeHtml(s)
  t = t.replace(/`([^`]+)`/g, '<code>$1</code>')
  t = t.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
  t = t.replace(/(^|[^*])\*([^*]+)\*/g, '$1<em>$2</em>')
  t = t.replace(/~~([^~]+)~~/g, '<del>$1</del>')
  t = t.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>')
  return t
}

function mdToHtml(md) {
  if (!md) return '<p class="rte__empty">Nothing to preview.</p>'
  const lines = md.split('\n')
  const out = []
  let inUl = false, inOl = false, inQuote = false

  const closeLists = () => {
    if (inUl) { out.push('</ul>'); inUl = false }
    if (inOl) { out.push('</ol>'); inOl = false }
    if (inQuote) { out.push('</blockquote>'); inQuote = false }
  }

  for (const line of lines) {
    if (/^\s*$/.test(line)) { closeLists(); continue }

    let m
    if ((m = line.match(/^###\s+(.*)$/))) { closeLists(); out.push(`<h3>${inline(m[1])}</h3>`); continue }
    if ((m = line.match(/^##\s+(.*)$/)))  { closeLists(); out.push(`<h2>${inline(m[1])}</h2>`); continue }
    if ((m = line.match(/^#\s+(.*)$/)))   { closeLists(); out.push(`<h1>${inline(m[1])}</h1>`); continue }
    if (/^---+$/.test(line))              { closeLists(); out.push('<hr />'); continue }

    if ((m = line.match(/^>\s?(.*)$/))) {
      if (!inQuote) { closeLists(); out.push('<blockquote>'); inQuote = true }
      out.push(`<p>${inline(m[1])}</p>`)
      continue
    }
    if ((m = line.match(/^-\s+\[( |x|X)\]\s+(.*)$/))) {
      if (!inUl) { closeLists(); out.push('<ul class="rte__checks">'); inUl = true }
      const checked = m[1].toLowerCase() === 'x'
      out.push(`<li><input type="checkbox" disabled ${checked ? 'checked' : ''} /> ${inline(m[2])}</li>`)
      continue
    }
    if ((m = line.match(/^[-*]\s+(.*)$/))) {
      if (!inUl) { closeLists(); out.push('<ul>'); inUl = true }
      out.push(`<li>${inline(m[1])}</li>`)
      continue
    }
    if ((m = line.match(/^\d+\.\s+(.*)$/))) {
      if (!inOl) { closeLists(); out.push('<ol>'); inOl = true }
      out.push(`<li>${inline(m[1])}</li>`)
      continue
    }

    closeLists()
    out.push(`<p>${inline(line)}</p>`)
  }
  closeLists()
  return out.join('\n')
}

const previewHtml = computed(() => mdToHtml(props.modelValue || ''))

defineExpose({ mdToHtml })
</script>

<style scoped>
.rte {
  border: 1px solid rgba(15, 23, 42, 0.18);
  border-radius: 12px;
  background: #fff;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
  overflow: hidden;
}
.rte--focused {
  border-color: rgb(13, 148, 136);
  box-shadow: 0 0 0 2px rgba(13, 148, 136, 0.15);
}
.rte__toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 4px;
  padding: 6px 8px;
  background: rgba(15, 23, 42, 0.03);
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
}
.rte__group { background: transparent; }

.rte__textarea {
  display: block;
  width: 100%;
  border: 0;
  outline: none;
  resize: vertical;
  padding: 14px 16px;
  font-family: inherit;
  font-size: 0.95rem;
  line-height: 1.55;
  color: rgb(15, 23, 42);
  background: transparent;
  box-sizing: border-box;
}
.rte__preview {
  padding: 14px 16px;
  line-height: 1.55;
  font-size: 0.95rem;
  color: rgb(15, 23, 42);
  overflow-y: auto;
}
.rte__preview :deep(h1) { font-size: 1.5rem; font-weight: 700; margin: 0.5em 0 0.3em; }
.rte__preview :deep(h2) { font-size: 1.25rem; font-weight: 700; margin: 0.5em 0 0.3em; }
.rte__preview :deep(h3) { font-size: 1.1rem; font-weight: 700; margin: 0.5em 0 0.3em; }
.rte__preview :deep(p) { margin: 0.4em 0; }
.rte__preview :deep(ul),
.rte__preview :deep(ol) { padding-left: 1.5em; margin: 0.4em 0; }
.rte__preview :deep(blockquote) {
  border-left: 3px solid rgba(13,148,136,0.5);
  padding: 4px 10px; color: rgba(15,23,42,0.75); margin: 0.4em 0;
  background: rgba(13,148,136,0.05); border-radius: 4px;
}
.rte__preview :deep(code) {
  background: rgba(15,23,42,0.06); padding: 1px 4px; border-radius: 4px;
  font-family: ui-monospace, "SFMono-Regular", Menlo, monospace; font-size: 0.85em;
}
.rte__preview :deep(a) { color: rgb(13,148,136); text-decoration: underline; }
.rte__preview :deep(hr) { border: 0; border-top: 1px solid rgba(15,23,42,0.12); margin: 0.8em 0; }
.rte__preview :deep(.rte__checks) { list-style: none; padding-left: 0.2em; }
.rte__preview :deep(.rte__empty) { color: rgba(15,23,42,0.45); font-style: italic; }

:global(.v-theme--dark) .rte {
  background: rgb(30, 41, 59);
  border-color: rgba(255, 255, 255, 0.12);
}
:global(.v-theme--dark) .rte__toolbar {
  background: rgba(255, 255, 255, 0.04);
  border-bottom-color: rgba(255, 255, 255, 0.08);
}
:global(.v-theme--dark) .rte__textarea,
:global(.v-theme--dark) .rte__preview { color: rgb(226, 232, 240); }
:global(.v-theme--dark) .rte__preview :deep(code) { background: rgba(255,255,255,0.08); }
:global(.v-theme--dark) .rte__preview :deep(blockquote) {
  background: rgba(13,148,136,0.1); color: rgba(226,232,240,0.85);
}
</style>
