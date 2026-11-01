// Lexical GLua normalization for offline parsing. Not a GMod interpreter.
// Strings/comments are protected; continue is only a syntax-check placeholder.
exports.normalize = function(source) {
  return source.replace(/--\[(=*)\[[\s\S]*?\]\1\]|\[(=*)\[[\s\S]*?\]\2\]|--[^\r\n]*|\/\/[^\r\n]*|\/\*[\s\S]*?\*\/|"(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*'|!=|&&|\|\||!|\bcontinue\b/g, token => {
    if (token.startsWith('//')) return '--' + token.slice(2);
    if (token.startsWith('/*')) return token.replace(/[^\r\n]/g, ' ');
    return ({'!=':'~=', '&&':' and ', '||':' or ', '!':'not ', continue:'break'})[token] || token;
  });
};
