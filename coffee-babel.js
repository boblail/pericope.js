// Compile test file with coffeescript and then compile it again with Babel
// http://www.justgoscha.com/programming/2016/04/11/Mocha-Testing-with-ES6-modules-babel.html

var fs = require('fs');
var coffee = require("coffee-script");
var babel = require("babel-core");

require.extensions['.coffee'] = function(module, filename) {
  var content = fs.readFileSync(filename, 'utf8');
  var compiled = coffee.compile(content, {bare: true});
  compiled = babel.transform(compiled, {presets:["es2015"]}).code;
  return module._compile(compiled, filename); // module._compile is not mentioned in the Node docs, what is it? And why is it private-ish?
};
