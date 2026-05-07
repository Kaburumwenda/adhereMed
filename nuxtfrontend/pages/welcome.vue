<template>
  <NuxtLayout name="auth">
    <div class="welcome-root">
      <div class="brand-gradient bg-fill" />
      <div class="blob blob-1" />
      <div class="blob blob-2" />
      <div class="blob blob-3" />

      <!-- Top nav -->
      <div class="top-nav d-flex align-center px-4 px-md-12 py-3">
        <div
          class="d-flex align-center justify-center mr-2"
          style="width:34px;height:34px;border-radius:9px;background:rgba(255,255,255,0.15);border:1px solid rgba(255,255,255,0.25);"
        >
          <v-icon size="17" color="white">mdi-heart</v-icon>
        </div>
        <BrandMark :size="16" bold-color="white" light-color="white" />
        <v-spacer />
        <v-btn
          variant="outlined"
          color="white"
          class="text-none mr-2"
          rounded="lg"
          @click="$router.push('/login')"
        >
          Sign In
        </v-btn>
        <v-btn
          color="white"
          class="text-none"
          rounded="lg"
          style="color:#0F766E;"
          @click="$router.push('/register-facility')"
        >
          Register
        </v-btn>
      </div>

      <!-- Hero -->
      <v-container class="content-wrapper text-center" style="position:relative;z-index:2;">
        <div class="mt-16 mb-2 d-flex justify-center">
          <BrandLogo :size="72" />
        </div>
        <div class="mb-2 d-flex justify-center">
          <span class="text-h3 text-md-h2 font-weight-bold text-white">Adhere</span>
          <span class="text-h3 text-md-h2 font-weight-light" style="color:#5EEAD4;">Med</span>
        </div>
        <p class="text-h6 font-weight-light mb-12" style="color:rgba(255,255,255,0.88);">
          Connected Healthcare.<br>Simplified.
        </p>

        <!-- Feature grid -->
        <v-row justify="center" class="mb-12">
          <v-col v-for="f in features" :key="f.title" cols="12" sm="6" md="3">
            <div class="feature-card pa-5 rounded-lg text-left">
              <v-icon :color="f.color" size="32" class="mb-3">{{ f.icon }}</v-icon>
              <div class="text-body-1 font-weight-bold text-white mb-1">{{ f.title }}</div>
              <div class="text-body-2" style="color:rgba(255,255,255,0.7);">{{ f.desc }}</div>
            </div>
          </v-col>
        </v-row>

        <!-- CTAs -->
        <div class="d-flex flex-column flex-sm-row justify-center ga-3 mb-8">
          <v-btn
            size="large"
            color="white"
            class="text-none px-8"
            rounded="lg"
            style="color:#0F766E;"
            @click="$router.push('/login')"
          >
            <v-icon class="mr-2">mdi-login</v-icon> Sign In
          </v-btn>
          <v-btn
            size="large"
            variant="outlined"
            color="white"
            class="text-none px-8"
            rounded="lg"
            @click="$router.push('/register')"
          >
            <v-icon class="mr-2">mdi-account-plus</v-icon> Create Account
          </v-btn>
        </div>

        <p class="text-caption mb-6" style="color:rgba(255,255,255,0.45);">
          © 2026 AdhereMed. Powering Healthcare Excellence.
        </p>
      </v-container>
    </div>
  </NuxtLayout>
</template>

<script setup>
definePageMeta({ layout: false })

const features = [
  { icon: 'mdi-hospital-building', title: 'Hospitals', desc: 'Patients, consultations, billing & more', color: '#5EEAD4' },
  { icon: 'mdi-pharmacy', title: 'Pharmacies', desc: 'POS, inventory, dispensing & analytics', color: '#7DD3FC' },
  { icon: 'mdi-flask', title: 'Laboratories', desc: 'Lab orders, results & exchange', color: '#F9A8D4' },
  { icon: 'mdi-account-heart', title: 'Patients', desc: 'Records, prescriptions & online orders', color: '#FBBF24' }
]
</script>

<style scoped>
.welcome-root {
  position: relative;
  min-height: 100vh;
  overflow: hidden;
}
.bg-fill {
  position: absolute;
  inset: 0;
  z-index: 0;
}
.top-nav {
  position: relative;
  z-index: 3;
}
.content-wrapper {
  position: relative;
  z-index: 2;
}
.blob {
  position: absolute;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.06);
  z-index: 1;
}
.blob-1 { top: -60px; right: -60px; width: 260px; height: 260px; }
.blob-2 { bottom: 80px; left: -80px; width: 320px; height: 320px; }
.blob-3 { top: 35%; right: -40px; width: 140px; height: 140px; background: rgba(255,255,255,0.07); }
.feature-card {
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.15);
  backdrop-filter: blur(8px);
  height: 100%;
}
</style>
