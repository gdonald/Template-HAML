
use Template::Haml::Grammar;
use Template::Haml::Lines;
use Template::Haml::Renderer;

class Haml is export {

  submethod BUILD() {

  }

  method parse(Str:D :$in) {
    Lines.clear;
    Grammar.parse($in);
    Renderer.render;
  }
}
