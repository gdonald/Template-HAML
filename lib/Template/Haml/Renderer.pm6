
use Template::Haml::Lines;

class Renderer is export {
  method render {
    Lines.entries.map({ $_.full }).join; # TODO
  }
}
