
unit module Template::HAML::Watch;

our sub glob-match(Str:D $pat, Str:D $str --> Bool) is export {
  my @pc = $pat.comb;
  my @sc = $str.comb;
  my $pi = 0;
  my $si = 0;
  my $star-pi = -1;
  my $star-si = 0;
  while $si < @sc.elems {
    if $pi < @pc.elems && (@pc[$pi] eq @sc[$si] || @pc[$pi] eq '?') {
      $pi++; $si++;
    } elsif $pi < @pc.elems && @pc[$pi] eq '*' {
      $star-pi = $pi;
      $star-si = $si;
      $pi++;
    } elsif $star-pi >= 0 {
      $pi = $star-pi + 1;
      $star-si++;
      $si = $star-si;
    } else {
      return False;
    }
  }
  while $pi < @pc.elems && @pc[$pi] eq '*' { $pi++ }
  $pi == @pc.elems;
}

class GlobPattern is export {
  has Str  $.dir is required;
  has Str  $.pattern is required;
  has Bool $.is-glob is required;

  method matches(Str:D $name --> Bool) {
    return $!pattern eq $name unless $!is-glob;
    glob-match($!pattern, $name);
  }

  method expand(--> Seq) {
    my $d = $!dir.IO;
    gather {
      last unless $d.d;
      if $!is-glob {
        for $d.dir -> $entry {
          next unless $entry.f;
          take $entry if self.matches($entry.basename);
        }
      } else {
        my $f = $d.add($!pattern);
        take $f if $f.f;
      }
    }
  }
}

our sub split-pattern(Str:D $s --> GlobPattern) is export {
  my $is-glob = so $s ~~ /<[*?]>/;
  my $p = $s.IO;
  my $dir  = ($p.parent // '.'.IO).Str;
  $dir = '.' unless $dir.chars;
  my $name = $p.basename;
  GlobPattern.new(:$dir, :pattern($name), :$is-glob);
}

our sub expand-inputs(@patterns --> Array) is export {
  my %seen;
  my @out;
  for @patterns -> $raw {
    my $gp = split-pattern($raw);
    for $gp.expand -> $path {
      my $key = $path.absolute;
      next if %seen{$key}++;
      @out.push($path);
    }
  }
  @out;
}

our sub mirror-output(IO::Path:D $input, IO::Path:D $out-dir --> IO::Path) is export {
  my $base = $input.basename;
  my $stem = $base ~~ /^ (.*) '.' \w+ $/ ?? ~$0 !! $base;
  $out-dir.add("$stem.html");
}

class Watcher is export {
  has @.patterns;
  has &.render-one is required;
  has Int $.max-rebuilds;
  has Int $.poll-ms      = 0;
  has Bool $.use-polling = False;

  has Int $!rebuild-count = 0;
  has %!known-stamp;
  has Lock $!lock .= new;

  method !stamp(IO::Path:D $p --> Str) {
    CATCH { default { return ''; } }
    my $m = $p.modified.Rat;
    my $s = $p.s;
    my $h = $p.slurp(:bin).list.sum;
    "$m:$s:$h";
  }

  method !record-stamp(IO::Path:D $p) {
    %!known-stamp{$p.absolute} = self!stamp($p);
  }

  method !initial-render(--> Bool) {
    my @files = expand-inputs(@!patterns);
    my $ok = True;
    for @files -> $f {
      self!record-stamp($f);
      $ok = False unless &!render-one($f);
    }
    $ok;
  }

  method !maybe-stop(--> Bool) {
    $!max-rebuilds.defined && $!rebuild-count >= $!max-rebuilds;
  }

  method !handle-path(IO::Path:D $f --> Bool) {
    return False unless $f.f;
    my $key  = $f.absolute;
    my $prev = %!known-stamp{$key};
    my $cur  = self!stamp($f);
    return False if $prev.defined && $cur eq $prev;
    %!known-stamp{$key} = $cur;
    &!render-one($f);
    $!rebuild-count++;
    True;
  }

  method !file-matches(IO::Path:D $path --> Bool) {
    my $name   = $path.basename;
    my $parent = ($path.parent // '.'.IO).absolute;
    for @!patterns -> $raw {
      my $gp = split-pattern($raw);
      my $gp-dir = $gp.dir.IO.absolute;
      next unless $gp-dir eq $parent;
      return True if $gp.matches($name);
    }
    False;
  }

  method run(--> Int) {
    return 1 unless self!initial-render;
    return 0 if self!maybe-stop;
    if $!use-polling {
      self!run-polling;
    } else {
      self!run-notify;
    }
    0;
  }

  method !run-polling {
    my $interval = ($!poll-ms || 200) / 1000;
    loop {
      sleep $interval;
      my @paths = expand-inputs(@!patterns);
      for @paths -> $p {
        $!lock.protect: { self!handle-path($p) }
        return if self!maybe-stop;
      }
    }
  }

  method !run-notify {
    my %dirs;
    for @!patterns -> $raw {
      my $gp = split-pattern($raw);
      %dirs{$gp.dir.IO.absolute} = $gp.dir.IO;
    }

    my $done = Promise.new;
    my @taps;
    for %dirs.values -> $d {
      my $sup = IO::Notification.watch-path($d.absolute);
      @taps.push: $sup.tap(-> $event {
        my $path = $event.path.IO;
        return unless self!file-matches($path);
        $!lock.protect: { self!handle-path($path) }
        $done.keep(True) if self!maybe-stop && $done.status ~~ Planned;
      });
    }

    LEAVE { .close for @taps }
    await $done;
  }
}
