/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        forest: {
          DEFAULT: '#033300',
          light: '#0a4d00',
          soft: '#e6ede4',
        },
        gold: {
          DEFAULT: '#ffc800',
          dark: '#d9a900',
          soft: '#fff6d6',
        },
        surface: '#f4f6f4',
      },
      fontFamily: {
        sans: ['Inter', 'Segoe UI', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
