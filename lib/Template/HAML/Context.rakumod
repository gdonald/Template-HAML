
unit class Template::HAML::Context is export;

has $.haml is rw;
has %.content-blocks;
has Str $.yield-content is rw = '';
has Int $.partial-depth is rw = 0;
has Int $.partial-depth-limit is rw = 100;
has Str $.current-dir is rw;
has $.user-context is rw;

method set-content(Str $name, Str $value) {
  %!content-blocks{$name} = $value;
}

method get-content(Str $name --> Str) {
  %!content-blocks{$name} // '';
}

method has-content(Str $name --> Bool) {
  %!content-blocks{$name}:exists;
}
