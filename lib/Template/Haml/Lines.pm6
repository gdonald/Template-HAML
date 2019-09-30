
class Lines is export {
  my @.entries;

  method push(Mu:D :$obj) {
    @.entries.push: $obj;
  }

  method clear {
    @.entries = ();
  }
}
