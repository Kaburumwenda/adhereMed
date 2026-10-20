<template>
  <div class="sig-pad" :class="{ 'sig-pad--disabled': disabled, 'sig-pad--signed': hasInk }">
    <canvas
      ref="canvasEl"
      class="sig-pad__canvas"
      :style="{ height: `${height}px` }"
      @pointerdown="onPointerDown"
      @pointermove="onPointerMove"
      @pointerup="onPointerUp"
      @pointerleave="onPointerUp"
      @pointercancel="onPointerUp"
    />

    <!-- Baseline guide, hidden once the user starts signing. -->
    <div v-if="!hasInk" class="sig-pad__placeholder" aria-hidden="true">
      <v-icon size="18">mdi-gesture-swipe</v-icon>
      <span>{{ placeholder }}</span>
    </div>

    <button
      v-if="hasInk && !disabled"
      type="button"
      class="sig-pad__clear"
      title="Clear signature"
      @click="clear"
    >
      <v-icon size="14">mdi-eraser</v-icon>
      <span>Clear</span>
    </button>
  </div>
</template>

<script setup>
import { ref, watch, onMounted, onBeforeUnmount, nextTick } from 'vue'

const props = defineProps({
  /** Base64 PNG data-URL of the current signature (empty string = unsigned). */
  modelValue: { type: String, default: '' },
  height: { type: Number, default: 150 },
  disabled: { type: Boolean, default: false },
  placeholder: { type: String, default: 'Sign here with your mouse, finger or stylus' },
})

const emit = defineEmits(['update:modelValue', 'update:hasInk'])

const canvasEl = ref(null)
const hasInk = ref(false)

let ctx = null
let drawing = false
let initialized = false
let resizeObserver = null

const INK = '#0f172a'
const LINE_WIDTH = 2.2

function paintBlank() {
  if (!ctx || !canvasEl.value) return
  const cv = canvasEl.value
  ctx.save()
  ctx.setTransform(1, 0, 0, 1, 0, 0)
  ctx.fillStyle = '#ffffff'
  ctx.fillRect(0, 0, cv.width, cv.height)
  ctx.restore()
}

/** Restore an existing signature (e.g. when re-opening the dialog). */
function drawFromDataUrl(dataUrl) {
  if (!ctx || !canvasEl.value) return
  const img = new Image()
  img.onload = () => {
    if (!ctx || !canvasEl.value) return
    const cv = canvasEl.value
    ctx.save()
    ctx.setTransform(1, 0, 0, 1, 0, 0)
    ctx.drawImage(img, 0, 0, cv.width, cv.height)
    ctx.restore()
    hasInk.value = true
    emit('update:hasInk', true)
  }
  img.src = dataUrl
}

function init() {
  const cv = canvasEl.value
  if (!cv || initialized) return
  const rect = cv.getBoundingClientRect()
  if (rect.width < 10) return  // dialog still hidden — wait for layout

  const dpr = window.devicePixelRatio || 1
  cv.width = Math.max(1, Math.floor(rect.width * dpr))
  cv.height = Math.max(1, Math.floor(props.height * dpr))

  ctx = cv.getContext('2d')
  if (!ctx) return
  ctx.scale(dpr, dpr)
  ctx.lineWidth = LINE_WIDTH
  ctx.lineCap = 'round'
  ctx.lineJoin = 'round'
  ctx.strokeStyle = INK

  paintBlank()
  initialized = true

  if (props.modelValue) {
    drawFromDataUrl(props.modelValue)
  } else {
    hasInk.value = false
    emit('update:hasInk', false)
  }
}

function pointAt(e) {
  const rect = canvasEl.value.getBoundingClientRect()
  return { x: e.clientX - rect.left, y: e.clientY - rect.top }
}

function onPointerDown(e) {
  if (props.disabled || !ctx) return
  drawing = true
  canvasEl.value.setPointerCapture?.(e.pointerId)
  const p = pointAt(e)
  ctx.beginPath()
  ctx.moveTo(p.x, p.y)
}

function onPointerMove(e) {
  if (!drawing || props.disabled || !ctx) return
  const p = pointAt(e)
  ctx.lineTo(p.x, p.y)
  ctx.stroke()
  if (!hasInk.value) {
    hasInk.value = true
    emit('update:hasInk', true)
  }
}

function onPointerUp() {
  if (!drawing) return
  drawing = false
  commit()
}

function commit() {
  if (!canvasEl.value || !hasInk.value) return
  const dataUrl = canvasEl.value.toDataURL('image/png')
  emit('update:modelValue', dataUrl)
}

function clear() {
  paintBlank()
  hasInk.value = false
  emit('update:hasInk', false)
  emit('update:modelValue', '')
}

// Parent resetting the model (e.g. new dialog open) wipes the canvas.
watch(
  () => props.modelValue,
  (value) => {
    if (!value && hasInk.value) clear()
  },
)

onMounted(() => {
  nextTick(() => {
    init()
    // Dialogs animate in, so the canvas often has no width at mount time.
    // Re-run init when the wrapper finally gets laid out.
    if (typeof ResizeObserver !== 'undefined' && canvasEl.value?.parentElement) {
      resizeObserver = new ResizeObserver(() => {
        if (!initialized) init()
      })
      resizeObserver.observe(canvasEl.value.parentElement)
    }
  })
})

onBeforeUnmount(() => {
  resizeObserver?.disconnect()
  resizeObserver = null
  ctx = null
})

defineExpose({ clear, hasInk })
</script>

<style scoped>
.sig-pad {
  position: relative;
  width: 100%;
  border-radius: 12px;
  overflow: hidden;
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.28);
  background:
    repeating-linear-gradient(
      0deg,
      transparent 0 29px,
      rgba(var(--v-theme-on-surface), 0.07) 29px 30px
    ),
    rgb(var(--v-theme-surface));
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
.sig-pad--signed {
  border-style: solid;
  border-color: rgba(var(--v-theme-primary), 0.5);
  box-shadow: 0 0 0 3px rgba(var(--v-theme-primary), 0.08);
}
.sig-pad--disabled {
  opacity: 0.6;
}
.sig-pad__canvas {
  display: block;
  width: 100%;
  touch-action: none;
  cursor: crosshair;
}
.sig-pad--disabled .sig-pad__canvas {
  cursor: not-allowed;
}
.sig-pad__placeholder {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  pointer-events: none;
  font-size: 12.5px;
  font-weight: 500;
  color: rgba(var(--v-theme-on-surface), 0.42);
}
.sig-pad__clear {
  position: absolute;
  top: 8px;
  right: 8px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 9px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.16);
  border-radius: 999px;
  background: rgb(var(--v-theme-surface));
  color: rgba(var(--v-theme-on-surface), 0.7);
  font-family: inherit;
  font-size: 11px;
  font-weight: 600;
  cursor: pointer;
  transition: color 0.15s ease, border-color 0.15s ease;
}
.sig-pad__clear:hover {
  color: rgb(var(--v-theme-error));
  border-color: rgba(var(--v-theme-error), 0.4);
}
</style>
