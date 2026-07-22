/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './components/**/*.{vue,js,ts}',
    './layouts/**/*.vue',
    './pages/**/*.vue',
    './composables/**/*.{js,ts}',
    './app.vue',
    './error.vue'
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        display: ['Sora', 'Inter', 'ui-sans-serif', 'sans-serif']
      },
      colors: {
        ink: {
          DEFAULT: '#0A0F1F',
          50: '#f4f6fb',
          100: '#e6ebf5',
          900: '#0A0F1F',
          950: '#050811'
        },
        brand: {
          50: '#eef5ff',
          100: '#d9e8ff',
          200: '#bcd7ff',
          300: '#8ebcff',
          400: '#5996ff',
          500: '#2f6dff',
          600: '#1a4ff5',
          700: '#143ce1',
          800: '#1731b6',
          900: '#192f8f',
          950: '#131d57'
        },
        cyanx: {
          400: '#37d6ff',
          500: '#0bb6e6'
        }
      },
      boxShadow: {
        glow: '0 0 40px -8px rgba(47,109,255,0.55)',
        'glow-lg': '0 0 80px -10px rgba(47,109,255,0.6)',
        card: '0 20px 60px -20px rgba(10,15,31,0.45)'
      },
      keyframes: {
        floaty: {
          '0%,100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-12px)' }
        },
        dash: {
          to: { strokeDashoffset: '-200' }
        },
        pulseGlow: {
          '0%,100%': { opacity: '0.4' },
          '50%': { opacity: '1' }
        },
        shimmer: {
          '100%': { transform: 'translateX(100%)' }
        },
        spinSlow: {
          to: { transform: 'rotate(360deg)' }
        }
      },
      animation: {
        floaty: 'floaty 6s ease-in-out infinite',
        dash: 'dash 3s linear infinite',
        pulseGlow: 'pulseGlow 3s ease-in-out infinite',
        spinSlow: 'spinSlow 40s linear infinite'
      }
    }
  },
  plugins: []
}
