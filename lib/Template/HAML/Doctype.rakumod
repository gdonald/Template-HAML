
use Template::HAML::X;

class Doctype is export {
  has Int $.indent = 0;
  has Int $.line;
  has Int $.column;
  has Str $.arg;
  has Str $.encoding;
  has Str $.format = 'html5';

  submethod BUILD(
    Int :$!indent = 0, Int :$!line, Int :$!column,
    Str :$!arg = '', Str :$!encoding = '', Str :$!format = 'html5',
  ) {}

  method render(--> Str) {
    given $!arg {
      when ''         { self.default-doctype }
      when '5'        { '<!DOCTYPE html>' }
      when '1.1'      { '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">' }
      when 'Strict'   { '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">' }
      when 'Frameset' { '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">' }
      when 'Mobile'   { '<!DOCTYPE html PUBLIC "-//WAPFORUM//DTD XHTML Mobile 1.2//EN" "http://www.openmobilealliance.org/tech/DTD/xhtml-mobile12.dtd">' }
      when 'RDFa'     { '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">' }
      when 'Basic'    { '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.1//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd">' }
      when 'XML'      { self.xml-decl }
      default {
        X::HAML::UnknownDoctype.new(
          :line($!line), :column($!column), :arg($!arg),
        ).throw;
      }
    }
  }

  method default-doctype(--> Str) {
    given $!format {
      when 'html5'  { '<!DOCTYPE html>' }
      when 'html4'  { '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">' }
      when 'xhtml'  { '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">' }
      default       { '<!DOCTYPE html>' }
    }
  }

  method xml-decl(--> Str) {
    my $enc = $!encoding || 'utf-8';
    "<?xml version='1.0' encoding='$enc' ?>";
  }
}
