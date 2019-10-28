
class X::IllegalIndent is Exception {}
sub illegal-indent is export {
  die X::IllegalIndent.new: payload => 'Illegal indentation';
}

class X::DuplicateId is Exception {}
sub duplicate-id is export {
  die X::DuplicateId.new: payload => 'Duplicate ID attribute';
}
