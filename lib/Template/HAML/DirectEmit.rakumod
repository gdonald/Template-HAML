
use Template::HAML::Eval;
use Template::HAML::Helpers;
use Template::HAML::Renderer;
use Template::HAML::Tag;
use Template::HAML::X;

unit module Template::HAML::DirectEmit;

sub html-escape(Str() $s --> Str) is export {
  $s.subst('&', '&amp;', :g)
    .subst('<', '&lt;',  :g)
    .subst('>', '&gt;',  :g)
    .subst('"', '&quot;', :g)
    .subst("'", '&#39;', :g);
}

sub haml-indent(Int $base-level, Int $width --> Str) is export {
  my $tab = (try { $*HAML-TAB-OFFSET }) // 0;
  my $level = $base-level + $tab;
  $level = 0 if $level < 0;
  ' ' x ($level * $width);
}

sub haml-tag-open-rest(
  Tag:D $tag, %locals --> Str
) is export {
  my $has-splat = $tag.attrs.grep({ $_ ~~ AttrSplat }).elems > 0;
  my @expanded  = $has-splat ?? expand-splats($tag.attrs, %locals) !! $tag.attrs.list;
  my @resolved  = resolve-attrs(@expanded, %locals);
  if $has-splat {
    @resolved = merge-attr-pairs(
      @resolved,
      :shorthand-classes($tag.classes.list),
      :shorthand-ids($tag.ids.list),
    );
  }
  if $tag.obj-ref-args.elems {
    my ($cls, $id) = compute-obj-ref($tag, %locals);
    @resolved = inject-obj-ref-attrs(@resolved, $cls, $id);
  }
  '<' ~ $tag.name ~ $tag.render-attrs(:attrs(@resolved)) ~ $tag.open-suffix;
}

sub lookup-bare-ident(Str $name, %locals) {
  return (True, %locals{$name}) if %locals{$name}:exists;
  my $ctx  = (try { $*HAML-CTX }) // Nil;
  my $user = $ctx.defined ?? $ctx.user-context !! Nil;
  if $user.defined && $user.^can($name) {
    return (True, $user."$name"());
  }
  (False, Nil);
}

sub eval-bare-ident(
  Str $code, %locals,
  Int :$line = 0, Int :$column = 0
) is export {
  my ($found, $value) = lookup-bare-ident($code, %locals);
  return $value if $found;
  eval-haml($code, %locals, :$line, :$column);
}

sub eval-direct(
  &block, Str $code,
  Int :$line = 0, Int :$column = 0
) is export {
  CATCH {
    when X::HAML { .throw }
    default {
      X::HAML::Eval.new(
        :$code, :$line, :$column, :reason(.message),
      ).throw;
    }
  }
  block();
}

sub render-direct-tag-open(
  Tag:D $tag, %locals, Int :$offset = 0 --> Str
) is export {
  my $has-splat = $tag.attrs.grep({ $_ ~~ AttrSplat }).elems > 0;
  my @expanded  = $has-splat ?? expand-splats($tag.attrs, %locals) !! $tag.attrs.list;
  my @resolved  = resolve-attrs(@expanded, %locals);
  if $has-splat {
    @resolved = merge-attr-pairs(
      @resolved,
      :shorthand-classes($tag.classes.list),
      :shorthand-ids($tag.ids.list),
    );
  }
  if $tag.obj-ref-args.elems {
    my ($cls, $id) = compute-obj-ref($tag, %locals);
    @resolved = inject-obj-ref-attrs(@resolved, $cls, $id);
  }
  $tag.open(:$offset, :attrs(@resolved));
}
