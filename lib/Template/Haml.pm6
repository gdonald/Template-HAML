
use Data::Dump::Tree;

use Template::Haml::Actions;
use Template::Haml::Compiler;
use Template::Haml::Grammar;
use Template::Haml::Tree;

class Haml is export {
  method render(Str:D :$haml) {
    my $actions = Actions.new;
    Grammar.parse($haml, :$actions);
    ddt $actions.tree;
    Compiler.compile;
  }
}
