
use Template::HAML::Actions;
use Template::HAML::Renderer;
use Template::HAML::Grammar;

class HAML is export {
  method render(Str:D :$haml) {
    my $actions = Actions.new;
    Grammar.parse($haml, :$actions);
    Renderer.render($actions.tree);
  }
}
