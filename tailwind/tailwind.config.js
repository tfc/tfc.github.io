/** @type {import('tailwindcss').Config} */
module.exports = {
  content:
    [ "./src/**/*.hs"
    , "./**/*.hamlet"
    ],
  theme: {
    extend: {
      screens: {
        '3xl': '1800px',
      },
      backgroundImage: {
        'darkpaper': "linear-gradient(to right bottom, rgba(0, 32, 66, 0.5), rgba(0, 22, 44, 0.9)), url('/images/roughpaper.svg')"
      },
      typography: {
        DEFAULT: {
          css: {
            'blockquote p:first-of-type::before': { content: '' },
            'blockquote p:last-of-type::after': { content: '' }
          },
        },
      },
    },
  },
  plugins: [ require('@tailwindcss/typography') ],
}
