package Asterisk::config;
###########################################################
#		read and write asterisk config files
###########################################################
#	Copyright (c) 2005-2006  hoowa sun	P.R.China
#
#	See COPYRIGHT section in pod text below for usage and distribution rights.
#
#	<hoowa.sun@gmail.com>
#	www.perlchina.org / www.openpbx.cn
#	last modify 2006-2-19
###########################################################
$Asterisk::config::VERSION='0.6';

use strict;
use vars qw/@commit_list/;
use Fcntl ':flock';

sub new {
	my $self = {};
	bless $self;
	return $self;
}

##############################
#  METHOD
#  load config from file or from stream data
sub load_config {
	my $self = shift;
	my %args = @_;
#	my $filename = shift;
#	my $stream_data = shift;

	my @DATA;

	if (!$args{'stream_data'}) {
		open(DATA,"<$args{'filename'}") or die "$!";
		@DATA = <DATA>;
		close(DATA);
	} else {
		@DATA = split(/\n/,$args{'stream_data'});
	}
	chomp(@DATA);

	my (%DATA,$last_section_name);
	$DATA{'[unsection]'}={};
	foreach my $one_line (@DATA) {
		my $line_sp=&clean_string($one_line);
		next if ($line_sp eq '');#next if just comment

		#right [section]???
		if ($line_sp =~ /^\[(.+)\]/) {
			$DATA{$1}={};			$last_section_name = $1;			next;
		}

		#right sharp "#" ???
		if ($line_sp =~ /^\#/) {
			my $section_name = $last_section_name;
			$section_name = '[unsection]' if (!$section_name);
			$DATA{$section_name}{$line_sp}=[] if (!$DATA{$section_name}{$line_sp});

			push(@{$DATA{$section_name}{$line_sp}},$line_sp);
			next;
		}

		#right key/value???
		if ($line_sp =~ /\=/) {
			#split data and key
			my ($key,$value)=split(/\=(.*)/,$line_sp);

			$key =~ s/^(\s+)//;		$key =~ s/(\s+)$//;
			$value=~ s/^\>//g;	$value =~ s/^(\s+)//;	$value =~ s/(\s+)$//;

			my $section_name = $last_section_name;
			$section_name = '[unsection]' if (!$section_name);
			$DATA{$section_name}{$key}=[] if (!$DATA{$section_name}{$key});
			push(@{$DATA{$section_name}{$key}},$value);
			next;
		}

	}

	return(\%DATA,\@DATA);
}

#####################
#	cookie for our
#####################
sub check_nvd {
	if (shift=~/[^a-zA-Z0-9\.]/) {
		return(0);
	} else {
		return(1);
	}
}

sub check_value {
	if (shift=~/[^a-zA-Z0-9]/) {
		return(0);
	} else {
		return(1);
	}
}

sub check_digits {
	if (shift=~/[^0-9\*\#]/) {
		return(0);
	} else {
		return(1);
	}
}

sub check_number {
	if (shift=~/[^0-9]/) {
		return(0);
	} else {
		return(1);
	}
}

sub check_import_number {
	if (shift=~/[^0-9,\s]/) {
		return(0);
	} else {
		return(1);
	}
}

##############################
# clean ; data from string end
sub clean_string {
	my $string = shift;
	($string,undef)=split(/\;/,$string);
	$string =~ s/^(\s+)//;
	$string =~ s/(\s+)$//;
return($string);
}

# split key value of data
sub clean_keyvalue {
	my $string = shift;
	my ($key,$value)=split(/\=(.*)/,$string);
	$key =~ s/^(\s+)//;		$key =~ s/(\s+)$//;
	if ($value) {
		$value=~ s/^\>//g;		$value =~ s/^(\s+)//;	$value =~ s/(\s+)$//;
	}
return($key,$value);
}

# income scalar,array ref,hash ref output array data
sub format_convert {
	my $string = shift;
	if (ref($string) eq 'ARRAY') {
		return(@$string);
	} elsif (ref($string) eq 'HASH') {
		my @tmp;
		foreach  (keys(%$string)) {
			push(@tmp,"$_=".$string->{$_});
		}
		return(@tmp);
	} else {
		return($string);
	}
}

##############################
#  METHOD
#  clean all assign before
sub clean_assign {
	undef(@commit_list);
}

##############################
#  METHOD
#  assign_cleanfile ; all data from file
sub assign_cleanfile {
	my $self = shift;
	my %hash = @_;
	$hash{'action'}='cleanfile';
	push(@commit_list,\%hash);
}

##############################
#  METHOD
#  replace data when matched
#  assign_matchreplace(match=>,replace=>);
sub assign_matchreplace {
	my $self = shift;
	my %hash = @_;
	$hash{'action'}='matchreplace';
	push(@commit_list,\%hash);
}

##############################
#  METHOD
#  assign append in anywhere
#  any section: up/down
#  assign_append(point=>'up'|'down',section=>,data=>[key=value,key=value]|{key=>value,key=>value}|'key=value');
#  any section&key-value: up/down/over
#  assign_append(point=>'up'|'down'|'over',section=>,comkey=>[key,value],data=>[key=value,key=value]|{key=>value,key=>value}|'key=value');  
#  no section:
#  assign_append(point=>'up'|'down',data=>[key=value,key=value]|{key=>value,key=>value}|'key=value');
sub assign_append {
	my $self = shift;
	my %hash = @_;
	$hash{'action'}='append';
	push(@commit_list,\%hash);
}

##############################
#  METHOD
#  replace the section except sharp "#"
#  any section/[unsection]:
#  assign_replacesection(section=>,data=>[key=value,key=value]|{key=>value,key=>value}|'key=value');
sub assign_replacesection {
	my $self = shift;
	my %hash = @_;
	$hash{'action'}='replacesection';
	push(@commit_list,\%hash);
}

##############################
#  METHOD
#  delete section
#  any section/[unsection]:
#  assign_delsection(section=>);
sub assign_delsection {
	my $self = shift;
	my %hash = @_;
	$hash{'action'}='delsection';
	push(@commit_list,\%hash);
}

##############################
#  METHOD
#  edit key
#  any section/[unsection]: change all matched key when key value are null.
#  assign_editkey(section=>,key=>,value=>,new_value=>);
sub assign_editkey {
	my $self = shift;
	my %hash = @_;
	$hash{'action'}='editkey';
	push(@commit_list,\%hash);
}

##############################
#  METHOD
#  delete key
#  any section/[unsection]: change all matched key when key value are null.
#  assign_delkey(section=>,key=>,$value=>);
sub assign_delkey {
	my $self = shift;
	my %hash = @_;
	$hash{'action'}='delkey';
	push(@commit_list,\%hash);
}

##############################
#  METHOD
#  save to file
#  filename: run assign rules and save to file
#  save_file(filename=>,resource=>);
sub save_file {
	my $self = shift;
	my %args = @_;

	if (!$args{'resource'}) {
		open(DATA,"<$args{'filename'}") or die "$!";
		my @DATA = <DATA>;
		close(DATA);
		chomp(@DATA);
		$args{'resource'}=\@DATA;
	}

	foreach my $one_case (@commit_list) {
		$args{'resource'} = &do_editkey($one_case,$args{'resource'}) if ($one_case->{'action'} eq 'editkey' || $one_case->{'action'} eq 'delkey');
		$args{'resource'} = &do_delsection($one_case,$args{'resource'}) if ($one_case->{'action'} eq 'delsection' || $one_case->{'action'} eq 'replacesection');
		$args{'resource'} = &do_append($one_case,$args{'resource'}) if ($one_case->{'action'} eq 'append');
		$args{'resource'} = &do_matchreplace($one_case,$args{'resource'}) if ($one_case->{'action'} eq 'matchreplace');
		if ($one_case->{'action'} eq 'cleanfile') {
			undef($args{'resource'});
			last;
		}
	}


	#save file
	open(SAVE,">$args{'filename'}") or die ("$!");
	flock(SAVE,LOCK_EX);
	print SAVE grep{$_.="\n"} @{$args{'resource'}};
	flock(SAVE,LOCK_UN);
	close(SAVE);
return();
}

##########################
# kernel do
sub do_matchreplace {
	my $one_case = shift;
	my $data = shift;
	my @NEW;

	foreach my $one_line (@$data) {
		if ($one_line =~ /$one_case->{'match'}/) {
			$one_line = $one_case->{'replace'};
		}
		push(@NEW,$one_line);
	}

return(\@NEW);
}

sub do_append {
	my $one_case = shift;
	my $data = shift;
	my @NEW;

	if ($one_case->{'section'} eq '') {
	#Append data head of source data/foot of source data
		if ($one_case->{'point'} eq 'up') {
			push(@NEW,&format_convert($one_case->{'data'}),@$data);
		} else {
			push(@NEW,@$data,&format_convert($one_case->{'data'}));
		}

	} elsif ($one_case->{'comkey'} eq '') {
	#Append data head/foot of section_name
		my $auto_save=0;
		foreach my $one_line (@$data) {
			#tune on auto save
			if ($auto_save) {			push(@NEW,$one_line);			next;		}
			#check section
			my $line_sp=&clean_string($one_line);
			my ($section_name) = $line_sp =~ /^\[(.+)\]/;
			if ($one_case->{'section'} eq $section_name & $one_case->{'point'} eq 'up') {
				push(@NEW,&format_convert($one_case->{'data'}));	$auto_save=1;
			} elsif ($one_case->{'section'} eq $section_name & $one_case->{'point'} eq 'down') {
				push(@NEW,$one_line);	push(@NEW,&format_convert($one_case->{'data'}));
				$one_line=undef;		$auto_save=1;
			}
			push(@NEW,$one_line);
		}

	} else {

		my $last_section_name='[unsection]';	#当前是默认的section
		my $auto_save=0;
		foreach my $one_line (@$data) {

			#tune on auto save
			if ($auto_save) {			push(@NEW,$one_line);			next;		}

			my $line_sp=&clean_string($one_line);
			#检查当前是不是进入了新的section
			if ($line_sp =~ /^\[(.+)\]/) {
				$last_section_name = $1;
			} elsif ($last_section_name eq $one_case->{'section'} & $line_sp =~ /\=/) {
				#split data and key
				my ($key,$value)=&clean_keyvalue($line_sp);
				if ($key eq $one_case->{comkey}[0] & $value eq $one_case->{comkey}[1] & $one_case->{'point'} eq 'up') {
					push(@NEW,&format_convert($one_case->{'data'}));	$auto_save=1;
				} elsif ($key eq $one_case->{comkey}[0] & $value eq $one_case->{comkey}[1] & $one_case->{'point'} eq 'down') {
					push(@NEW,$one_line);	push(@NEW,&format_convert($one_case->{'data'}));
					$one_line=undef;		$auto_save=1;
				} elsif ($key eq $one_case->{comkey}[0] & $value eq $one_case->{comkey}[1] & $one_case->{'point'} eq 'over') {
					push(@NEW,&format_convert($one_case->{'data'}));
					$one_line=undef;		$auto_save=1;
				}
			}
			push(@NEW,$one_line) if ($one_line);
		}

	}

return(\@NEW);
}

sub do_delsection {
	my $one_case = shift;
	my $data = shift;
	my @NEW;
	my $last_section_name='[unsection]';	#当前是默认的section
	my $auto_save=0;

	push(@NEW,&format_convert($one_case->{'data'})) if ($one_case->{'section'} eq '[unsection]' and $one_case->{'action'} eq 'replacesection');

	foreach my $one_line (@$data) {

		#tune on auto save
		if ($auto_save) {			push(@NEW,$one_line);			next;		}

		my $line_sp=&clean_string($one_line);

		if ($last_section_name eq $one_case->{'section'} & $line_sp =~ /^\[(.+)\]/) {
			#when end of compared section and come new different section
			$auto_save = 1;
		} elsif ($last_section_name eq $one_case->{'section'}) {
			next;
		} elsif ($line_sp =~ /^\[(.+)\]/) {
			#is this new section?
			if ($one_case->{'section'} eq $1) {
				$last_section_name = $1;
				next if ($one_case->{'action'} eq 'delsection');
				push(@NEW,$one_line);
				push(@NEW,&format_convert($one_case->{'data'}));
				$one_line=undef;
			}
		}

		push(@NEW,$one_line);
	}

return(\@NEW);
}

sub do_editkey {
	my $one_case = shift;
	my $data = shift;
	my @NEW;
	my $last_section_name='[unsection]';	#当前是默认的section
	my $auto_save=0;
	foreach my $one_line (@$data) {

		#tune on auto save
		if ($auto_save) {			push(@NEW,$one_line);			next;		}

		my $line_sp=&clean_string($one_line);

		#检查当前是不是进入了新的section
		if ($line_sp =~ /^\[(.+)\]/) {
			$last_section_name = $1;
		} elsif ($last_section_name eq $one_case->{section} & $line_sp =~ /\=/) {
			#split data and key
			my ($key,$value)=&clean_keyvalue($line_sp);

			if ($key eq $one_case->{'key'} && !$one_case->{'value'}) {			#处理全部匹配的key的value值
				$one_line = "$key=".$one_case->{'new_value'};
				undef($one_line) if ($one_case->{'action'} eq 'delkey');
			} elsif ($key eq $one_case->{'key'} && $one_case->{'value'} eq $value) {	#处理唯一匹配的key的value值
				$one_line = "$key=".$one_case->{'new_value'};
				undef($one_line) if ($one_case->{'action'} eq 'delkey');
				$auto_save = 1;
			}
		}

		push(@NEW,$one_line) if ($one_line);
	}

return(\@NEW);
}

=head1 NAME

Asterisk::config - the Asterisk config read and write module.

=head1 SYNOPSIS

	use Asterisk::config;

	my $rc = new Asterisk::config;
	my ($cfg,$res) = $rc->load_config(filename=>[configfile],stream_data=>[strings]);

	print $cfg->{'[unsection]'}{'test'}[0];

	print $cfg->{'[global]'}{'allow'}[1];

	$rc->assign_append(point=>'down',data=>$user_data);

	$rc->save_file(filename=>[filename],resource=>$res);


=head1 DESCRIPTION

Asterisk::config know how Asterisk config difference with 
standard ini config. this moudle make interface for read and
write Asterisk config files and Asterisk extension configs.

=head1 METHOD

=head2 new

	my $rc = new Asterisk::config;

Instantiates a new object.

=head2 load_config

	$rc->(filename=>[configfile],stream_data=>[strings]);

load config from file or from stream data.

=over 2

=item * configfile -> config file path and name.

=item * stream_data -> instead of C<filename>, data from 
strings.

=back

=head2 assign_cleanfile

	$rc->assign_cleanfile();
	
be sure clean all data from current file.

=head2 assign_matchreplace

	$rc->assign_matchreplace(match=>,replace=>);

replace new data when matched.

=over 2

=item * match -> string of matched data.

=item * replace -> new data.

=back

=head2 assign_append

	$rc->assign_append(point=>['up'|'down'],
		section=>[section],
		data=>[key=value,key=value]|{key=>value,key=>value}|'key=value'
		);

append data around with section name.

=over 3

=item * point -> append data C<up> / C<down> with section.

=item * section -> matched section name, except [unsection].

=item * data -> new replace data in string/array/hash.

=back

	$rc->assign_append(point=>['up'|'down'|'over'],
		section=>[section],
		comkey=>[key,value],
		data=>[key=value,key=value]|{key=>value,key=>value}|'key=value'
		);

append data around with section name and key/value in same section.

=over 2

=item * point -> C<over> will overwrite with key/value matched.

=item * comkey -> match key and value.

=back

	$rc->assign_append(point=>'up'|'down',
		data=>[key=value,key=value]|{key=>value,key=>value}|'key=value'
		);

simple append data without any section.

=head2 assign_replacesection

	$rc->assign_replacesection(section=>[section],
		data=>[key=value,key=value]|{key=>value,key=>value}|'key=value'
		);

replace the section body data,except "#" in body.

=over 1

=item * section -> all section and [unsection].

=back

=head2 assign_delsection

	$rc->assign_delsection(section=>[section]);

erase section name and section data.

=over 1

=item * section -> all section and [unsection].

=back

=head2 assign_editkey

	$rc->assign_editkey(section=>[section],key=>[keyname],value=>[value],new_value=>[new_value]);

modify value with matched section.if don't assign value=> will replace all matched key. 

exp script:

	$rc->assign_editkey(section=>'990001',key=>'all',new_value=>'gsm');

data:

	all=g711
	all=ilbc

will convert to:

	all=gsm
	all=gsm


=head2 assign_delkey

	$rc->assign_delkey(section=>[section],key=>[keyname],value=>[value]);

erase all matched C<keyname> in section or in [unsection].

=head2 save_file

	$rc->save_file(filename=>[filename],resource=>[resource]);

process assign rules and save to file.

=over 2

=item * filename -> save to file name.

=item * resource -> instand of filename must resource return load_config or
file handle.

=back

=head2 clean_assign

	$rc->clean_assign();

clean all assign rules.

=head1 EXAMPLES

be come soon...


=head1 AUTHORS

Asterisk::config by hoowa sun.  This pod text by hoowa sun only.

=head1 COPYRIGHT

The Asterisk::config module is Copyright (c) 2005-2006 hoowa sun. P.R.China.
All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=head1 WARRANTY

The Asterisk::config is free Open Source software.

IT COMES WITHOUT WARRANTY OF ANY KIND.

=head1 SUPPORT

Please logon IRC://irc.freenode.org/ #perlchina, and call me:)

Pure chinese Forum available http://www.openpbx.cn

=cut

1;
