
use Template::Haml::Actions;
use Template::Haml::Grammar;
use Template::Haml::Lines;
use Template::Haml::Renderer;

class Haml is export {
  method parse(Str:D :$haml) {
    Lines.clear;
    my $actions = Actions.new;
    Grammar.parse($haml, :$actions);
    Renderer.render;
  }
}
