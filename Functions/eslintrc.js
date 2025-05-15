module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: "eslint:recommended",
  rules: {
    "no-unused-vars": "off",
  },
  overrides: [
    {
      files: ["**/*.js"],
      rules: {
        "no-unused-vars": "off",
      },
    },
  ],
};