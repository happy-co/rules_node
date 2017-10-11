var qux = require("./qux/qux.js");

module.exports = function() {
  return "Baz!! (and " + qux() + ")";
};
