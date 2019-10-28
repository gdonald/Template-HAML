
use Template::Haml::Actions;
use Template::Haml::Renderer;
use Template::Haml::Grammar;

class Haml is export {
  method render(Str:D :$haml) {
    my $actions = Actions.new;
    Grammar.parse($haml, :$actions);
    Renderer.render($actions.tree);
  }
}
