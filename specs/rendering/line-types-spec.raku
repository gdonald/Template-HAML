use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Actions;
use Template::HAML::Grammar;
use Template::HAML::Node;

my @line-types = <
  blank
  comment
  doctype
  filter
  plain
  silent-comment
  statement
  tag
>;

describe 'HAML grammar line-type fixtures', {
  for @line-types -> $name {
    it "parses the $name fixture", {
      my $src = "t/fixtures/lines/$name.haml".IO.slurp;
      my $tree = Node.new;
      $tree.add-child(Node.new);
      my $actions = Actions.new(:$tree);
      my $m = Grammar.parse($src, :$actions);
      expect($m).to.not.be-nil;
    }
  }
}
