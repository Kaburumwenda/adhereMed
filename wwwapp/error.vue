<template>
  <div class="flex min-h-screen flex-col items-center justify-center px-6 text-center">
    <div class="absolute inset-0 -z-10 grid-pattern opacity-50"></div>
    <AppLogo />
    <p class="mt-10 font-display text-7xl font-extrabold text-white sm:text-8xl">{{ error.statusCode }}</p>
    <h1 class="mt-3 font-display text-2xl font-bold text-white">
      {{ error.statusCode === 404 ? 'Page not found' : 'Something went wrong' }}
    </h1>
    <p class="mt-3 max-w-md text-slate-400">
      {{ error.statusCode === 404
        ? "The page you're looking for doesn't exist or has moved."
        : 'An unexpected error occurred. Please try again.' }}
    </p>
    <div class="mt-8 flex gap-3">
      <button class="btn-primary" @click="handleError">Back to home</button>
      <a :href="webAppUrl" target="_blank" rel="noopener" class="btn-ghost">Launch platform</a>
    </div>
  </div>
</template>

<script setup>
const { webAppUrl } = useAppLinks()
defineProps({ error: { type: Object, required: true } })

function handleError() {
  clearError({ redirect: '/' })
}
</script>
