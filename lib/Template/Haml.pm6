
use Template::Haml::Actions;
use Template::Haml::Grammar;
use Template::Haml::Lines;
use Template::Haml::Compiler;

class Haml is export {
  method compile(Str:D :$haml) {
    Lines.clear;
    my $actions = Actions.new;
    Grammar.parse($haml, :$actions);
    Compiler.compile;
  }
}
