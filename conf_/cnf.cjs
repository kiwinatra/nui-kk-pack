const path = require('path');

module.exports = { head: { meta: [
      { charset: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { name: 'theme-color', content: '#000000' }
    ] }, css: [
    '~/assets/css/main.css'
  ], buildModules: [
    '@nuxtjs/eslint-module'
  ], build: { extend(config, { isClient }) { if (isClient) { config.optimization.splitChunks.maxSize = 250000; } } } };