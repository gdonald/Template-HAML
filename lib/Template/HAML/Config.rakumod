
constant @DEFAULT-VOID-ELEMENTS = <
  area base br col embed hr img input link meta param source track wbr
>;

constant @DEFAULT-PRESERVE-ELEMENTS = <pre textarea>;

constant %ENCODING-ALIASES =
  'utf-8'        => 'utf-8',
  'utf8'         => 'utf-8',
  'utf-16'       => 'utf-16',
  'utf16'        => 'utf-16',
  'utf-16le'     => 'utf-16le',
  'utf-16be'     => 'utf-16be',
  'utf-32'       => 'utf-32',
  'utf32'        => 'utf-32',
  'ascii'        => 'ascii',
  'us-ascii'     => 'ascii',
  'iso-8859-1'   => 'iso-8859-1',
  'latin1'       => 'iso-8859-1',
  'latin-1'      => 'iso-8859-1',
  'windows-1252' => 'windows-1252',
  'cp1252'       => 'windows-1252',
;

sub canonical-encoding(Str:D $name --> Str) is export {
  %ENCODING-ALIASES{$name.lc} // $name.lc;
}

sub is-known-encoding(Str:D $name --> Bool) is export {
  %ENCODING-ALIASES{$name.lc}:exists;
}

class Template::HAML::Config is export {
  has Str  $.format          is rw = 'html5';
  has Bool $.escape-html     is rw = True;
  has Bool $.escape-attrs    is rw = True;
  has Str  $.output-style    is rw = 'pretty';
  has Str  $.attr-quote      is rw = "'";
  has Str  $.encoding        is rw = 'utf-8';
  has Bool $.suppress-eval   is rw = False;
  has Bool $.cdata           is rw = False;
  has Str  $.mime-type       is rw = '';
  has Bool $.hyphenate-data-attrs is rw = False;
  has Int  $.output-indent-width is rw = 2;
  has Bool $.remove-whitespace is rw = False;
  has Bool $.trace           is rw = False;
  has @.autoclose            is rw;
  has @.preserve             is rw;

  submethod BUILD(
    Str  :$!format          = 'html5',
    Bool :$!escape-html     = True,
    Bool :$!escape-attrs    = True,
    Str  :$!output-style    = 'pretty',
    Str  :$!attr-quote      = "'",
    Str  :$!encoding        = 'utf-8',
    Bool :$!suppress-eval   = False,
    Bool :$!cdata           = False,
    Str  :$!mime-type       = '',
    Bool :$!hyphenate-data-attrs = False,
    Int  :$!output-indent-width = 2,
    Bool :$!remove-whitespace = False,
    Bool :$!trace           = False,
    :@autoclose,
    :@preserve,
  ) {
    self.validate-format($!format);
    self.validate-output-style($!output-style);
    self.validate-attr-quote($!attr-quote);
    self.validate-encoding($!encoding);
    $!encoding = canonical-encoding($!encoding);
    @!autoclose = @autoclose.elems ?? @autoclose !! @DEFAULT-VOID-ELEMENTS;
    @!preserve  = @preserve.elems  ?? @preserve  !! @DEFAULT-PRESERVE-ELEMENTS;
  }

  method validate-format(Str $f) {
    die "invalid format '$f'; expected html5, html4, or xhtml"
      unless $f eq 'html5' || $f eq 'html4' || $f eq 'xhtml';
  }

  method validate-output-style(Str $s) {
    die "invalid output-style '$s'; expected pretty or ugly"
      unless $s eq 'pretty' || $s eq 'ugly';
  }

  method validate-attr-quote(Str $q) {
    die "invalid attr-quote '$q'; expected ' or \""
      unless $q eq "'" || $q eq '"';
  }

  method validate-encoding(Str $e) {
    die "invalid encoding '$e'; expected one of: "
      ~ %ENCODING-ALIASES.keys.sort.join(', ')
      unless is-known-encoding($e);
  }

  method is-xhtml(--> Bool) { $!format eq 'xhtml' }
  method is-html5(--> Bool) { $!format eq 'html5' }
  method is-html4(--> Bool) { $!format eq 'html4' }
  method is-html(--> Bool)  { $!format eq 'html5' || $!format eq 'html4' }

  method is-pretty(--> Bool) { $!output-style eq 'pretty' }
  method is-ugly(--> Bool)   { $!output-style eq 'ugly'   }

  method is-void(Str $name --> Bool) {
    $name (elem) @!autoclose;
  }

  method is-preserved(Str $name --> Bool) {
    $name (elem) @!preserve;
  }

  method default-doctype(--> Str) {
    given $!format {
      when 'html5' { '<!DOCTYPE html>' }
      when 'html4' { '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">' }
      when 'xhtml' { '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">' }
    }
  }

  #| Return a copy of this Config with the given attributes overridden.
  method clone-with(*%overrides) {
    my %args =
      format              => $!format,
      escape-html         => $!escape-html,
      escape-attrs        => $!escape-attrs,
      output-style        => $!output-style,
      attr-quote          => $!attr-quote,
      encoding            => $!encoding,
      suppress-eval       => $!suppress-eval,
      cdata               => $!cdata,
      mime-type           => $!mime-type,
      hyphenate-data-attrs => $!hyphenate-data-attrs,
      output-indent-width => $!output-indent-width,
      remove-whitespace   => $!remove-whitespace,
      trace               => $!trace,
      autoclose           => @!autoclose,
      preserve            => @!preserve,
    ;
    for %overrides.kv -> $k, $v {
      %args{$k} = $v;
    }
    Template::HAML::Config.new(|%args);
  }
}
