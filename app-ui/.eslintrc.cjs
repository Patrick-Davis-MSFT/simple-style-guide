module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module',
    ecmaFeatures: {
      jsx: true,
    },
  },
  plugins: ['react-hooks'],
  extends: ['eslint:recommended'],
  env: {
    browser: true,
    es2022: true,
  },
  globals: {
    Office: 'readonly',
    Word: 'readonly',
  },
  overrides: [
    {
      files: ['**/*.d.ts'],
      rules: {
        'no-unused-vars': 'off',
      },
    },
  ],
  rules: {
    'react-hooks/rules-of-hooks': 'error',
    'react-hooks/exhaustive-deps': 'warn',
  },
};
