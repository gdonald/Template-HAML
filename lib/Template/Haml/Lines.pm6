
class Lines is export {
  my @.entries;

  method push(Mu:D :$line) {
    @.entries.push: $line;
  }

  method clear {
    @.entries = ();
  }
}
