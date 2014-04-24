use strict;
use Encode;
use Tk;
use Tk::BrowseEntry;
use File::Find;
use FileHandle;
use File::Path qw(make_path);
use DBI;
use CZImporthelper;

# �趨���������ȱʡֵ�����ǵ�ֵ������ͨ�������в������޸�
my $directory='';
my $dirs='';
my $outdir='';
my $tables='';
my $sqlfilepath='';
my $filepath='';
my $deluser=1;
my $restats=0;
my $syspass='yourpass';
my $tbs='sccz';
my $hostname='localhost';
my $sid='orcl';
my $logfile='importlog.txt';
  
my @dmpfiles;                           #�����������д�����dmp�ļ���
my @statements;                         #�������Ŵ�SQL�ļ��ж�������my $dir='';

# ���洴�������ڣ���ֹ��resize�������������Թ�ʹ��
my $mw = Tk::MainWindow->new;
$mw->resizable(0,0);                    
$mw->geometry("550x450+100+100");
$mw->title(CT("��ӭʹ��CZImport��"));
my $code_font = $mw->fontCreate('code', -family => 'Microsoft Yahei', -size => 11);

$mw->Label(-text=>CT("������Oracle���������ڵ���������*"), -font=>$code_font)->place(-x=>10, -y=>10);
$mw->Entry(-relief=>'sunken', -width =>18, -font=>$code_font, -textvariable => \$hostname)->place(-x=>10, -y=>35);

$mw->Label(-text=>CT("������Oracle���������ڵ�SID��*"), -font=>$code_font)->place(-x=>300, -y=>10);
$mw->Entry(-relief=>'sunken', -width =>18, -font=>$code_font, -textvariable => \$sid)->place(-x=>300, -y=>35);

$mw->Label(-text=>CT("������sys�û������룺*"), -font=>$code_font)->place(-x=>10, -y=>60);
$mw->Entry(-relief=>'sunken', -width =>18, -font=>$code_font, -textvariable => \$syspass)->place(-x=>10, -y=>85);

$mw->Label(-text=>CT("�����뵼�����ݵı�ռ�����*"), -font=>$code_font)->place(-x=>300, -y=>60);
$mw->Entry(-relief=>'sunken', -width =>18, -font=>$code_font, -textvariable => \$tbs)->place(-x=>300, -y=>85);

$mw->Label(-text=>CT("��ѡ��dmp�ļ����ڵ��ļ��У�*"), -font=>$code_font)->place(-x=>10, -y=>115);
$mw->Entry(-relief=>'sunken', -width =>42, -state=>'disabled', -font=>$code_font, -textvariable => \$directory)->place(-x=>10, -y=>140);
$mw->Button(-text => CT("���"), -font=>$code_font, -anchor=>'n', -command => sub {$directory = CT($mw->chooseDirectory(-initialdir => '~', -title => CT('��ѡ��һ��Ŀ¼')))})->place(-x=>400, -y=>135);

$mw->Label(-text=>CT("��ѡ���ִ�е�SQL�ű���"), -font=>$code_font)->place(-x=>10, -y=>170);
$mw->Entry(-relief=>'sunken', -width =>42, -state=>'disabled', -font=>$code_font, -textvariable => \$filepath)->place(-x=>10, -y=>200);
$mw->Button(-text => CT("���"), -font=>$code_font, -anchor=>'n', -command => \&Open_Sqlfile)->place(-x=>400, -y=>195);

$mw->Label(-text=>CT("��ָ��Ҫ����ı��ö��ŷָ���Ĭ��Ϊ���б���"), -font=>$code_font)->place(-x=>10, -y=>230);
my $t=$mw->Scrolled("Text", -scrollbars => 'oe', -width=>50, -height=>4, -font=>$code_font)->place(-x=>10, -y=>260);
$mw->Checkbutton(-text => CT('ʹ����ɺ�ɾ���û��ͱ�'), -variable => \$deluser, -font=>$code_font)->place(-x=>10, -y=>350);
$mw->Checkbutton(-text => CT('�ؽ�ͳ����Ϣ'), -variable => \$restats, -font=>$code_font)->place(-x=>300, -y=>350);

$mw->Button(-text => CT("��ʼ��"), -command => \&ParseCommand, -font=>$code_font, -width=>10)->place(-x=>120, -y=>400);
$mw->Button(-text => CT("�˳�"), -command => sub { exit }, -font=>$code_font, -width=>10)->place(-x=>260, -y=>400);

Tk::MainLoop();

###################################################
#    CT�����������������ַ�����Decode����ֹ����          #
###################################################
sub CT
{
	my $str = shift @_;
	return decode("gb2312", $str);
}

#######################################################
#    Open_Sqlfile�����������������ļ��ĶԻ���ѡ��SQL�ű�  #
#######################################################
sub Open_Sqlfile
{
	my @types =
       (["SQL Files", [qw/.sql /]],
        ["TXT Files", [qw/.txt /]],
       );
   $filepath = $mw->getOpenFile(-filetypes => \@types);
}

########################################################
#    AddDumpFiles��������Ҫ��File::Findʹ�ã���--dir       #
#    ѡ���ʱ����ݹ�����ָ����Ŀ¼�����ҵ���dmp�ļ���         #
#    ��@dmpfiles����                                    #
########################################################
sub AddDumpFiles
{
	if (-f $File::Find::name) {
        if ($File::Find::name =~ /\.dmp$/) {
            push @dmpfiles, $File::Find::name;
        }
	}
}

#####################################################
#    ParseCommand�����������������Ƿ���ȷ              #
#    �������ȷ���򵯳�������ʾ�������ִ��ImportFile����   #
#####################################################
sub ParseCommand
{
    if(!$directory)
    {
        $mw->messageBox(-title => CT("��������"), -message=>CT("��ָ��dmp�ļ�����Ŀ¼��"), -type=>'Ok', -icon=>'error');
        return 1;
    }
    if(!$hostname)
    {
        $mw->messageBox(-title => CT("��������"), -message=>CT("��������������"), -type=>'Ok', -icon=>'error');
        return 1;
    }
    if(!$sid)
    {
        $mw->messageBox(-title => CT("��������"), -message=>CT("������SID��"), -type=>'Ok', -icon=>'error');
        return 1;
    }
    if(!$syspass)
    {
        $mw->messageBox(-title => CT("��������"), -message=>CT("������sys�û������룡"), -type=>'Ok', -icon=>'error');
        return 1;
    }
    if(!$tbs)
    {
        $mw->messageBox(-title => CT("��������"), -message=>CT("�������ռ����ƣ�"), -type=>'Ok', -icon=>'error');
        return 1;
    }
    
    $dirs = encode("gb2312", $directory);
    $sqlfilepath = encode("gb2312", $filepath);
    
    find(\&AddDumpFiles, $dirs);
    
    #���·����û���κ��ļ����򱨴��˳���
	if(@dmpfiles==0)
	{
        $mw->messageBox(-title => CT("��������"), -message=>CT("ָ��Ŀ¼��û��dmp�ļ���"), -type=>'Ok', -icon=>'error');
		return 1;
	}
		
	&ImportFile();
}

#############################################################
#    ImportFile�����������ǽ�������dmp�ļ�����������ݿ⡣          #
#    �����ʱ������dmp�ļ���basename������ͬ���û���              #
#    �������û�����ͬ���ú���������cu.sql�ļ���������SQLPlus        #
#    ��ִ�д����û�����Ȩ���ܣ�������imp�������ݡ�                 #
#############################################################
sub ImportFile
{
    my $filenum=0;                #����ͳ�ƴ�����ļ���
	my $timestamp=localtime;      #���ڻ�ȡʱ��
    open LOG, ">importlog.txt" or die "Cannot open log file to write!";
	print LOG "��ʼ����czimport����, ʱ����$timestamp.\n";
	print LOG '='x30, "\n";

	#�����ж��û�����ָ��sql�ű��ļ�������������ݲ��ֽ�Ϊ���SQL���
	if($sqlfilepath)
	{
		@statements=&ParseSQL($sqlfilepath);
    }
    
    #�������ÿ��dmp�ļ������е������
	foreach my $dmpfile (@dmpfiles)
	{
		my ($user_name, $dmp_dir)=&GetUserName($dmpfile);
		# ���潨��һ��cu.sql���ļ����ѽ����û�����Ȩ��SQL���д��ȥ����sqlplusִ��
		open CU, ">cu.sql" or die "Cannot open the sql file to write!";
		print CU "create user $user_name identified by $user_name default tablespace $tbs account unlock;\n";
		print CU "grant CONNECT to $user_name WITH ADMIN OPTION;\n";
		print CU "grant RESOURCE to $user_name WITH ADMIN OPTION;\n";
		print CU "grant DBA to $user_name WITH ADMIN OPTION;\n";
		print CU "exit;\n";
		close CU;
		system("sqlplus sys/$syspass\@$sid as sysdba \@cu.sql")==0 or die "Cannot execute user creation command.";
		$timestamp=localtime;
		print LOG "��ʼ����$dmpfile��ʱ����$timestamp.\n";

		#�ж�����--tablesѡ�������ָ����������ȫ����
		$tables=$t->get('1.0', 'end-1c');
		if($tables)
		{
			system("imp $user_name/$user_name\@$sid file=\'$dmpfile\' tables=($tables)");
		}
		else
		{
			system("imp $user_name/$user_name\@$sid file=\'$dmpfile\' full=y ignore=y");
		}

		$timestamp=localtime;
		print LOG "��������$dmpfile, ʱ����$timestamp.\n";
		$filenum++;
	
	    #�����ж��û�����ָ��sql�ű��ļ��������������ݿ�ִ��sql�ű�
		if($sqlfilepath)
		{
			#�������ݿⲢ�����ݿⲻ���ִ�Сд
			my $dbh=DBI->connect("dbi:Oracle:host=$hostname;sid=$sid", $user_name, $user_name) or die "Cannot conenct db: $DBI::errstr\n";
			my $case_insensitive_sth1=$dbh->prepare("ALTER SESSION SET NLS_COMP=ANSI");
			my $case_insensitive_sth2=$dbh->prepare("ALTER SESSION SET NLS_SORT=BINARY_CI");
			$case_insensitive_sth1->execute() or die "Cannot execute the query: $case_insensitive_sth1->errstr";
			$case_insensitive_sth2->execute() or die "Cannot execute the query: $case_insensitive_sth2->errstr";
			
			#�ж��Ƿ�Ҫ�ؽ�ͳ����Ϣ
            if($restats)
            {
                $dbh->do("begin\n dbms_stats.gather_schema_stats(\'$user_name\',estimate_percent=>100,cascade=> TRUE);\nEND;");
            }
			
			# ��������ִ�д��ļ��ж�ȡ��SQL��䣬��������ڡ�dmp�ļ���_����.csv���ļ���
			my $count=1;
			my $tname='';          #export������ı���
			my $iname='';          #insert������ı���
			my $saveout=0;         #�ж��Ƿ񱣴�ΪCSV
			my $insertdata=0;      #�ж��Ƿ�������ݿ�
			my $tmp;
			foreach my $statement (@statements)
			{
				$tmp=$statement;
				my $sth;
				
				#�ж����ǰ��û��"--export"ע�ͣ��оͱ���ΪCSV�ļ�������ͽ�ִ�����
				if($tmp=~/-{2,}export/i)
				{
					if($tmp=~s/-{2,}export (\S+) select/select/i)
					{
						$tname=$1;
						$tname=~s/\s+//g;
					}
					else
					{
						$tmp=~s/-{2,}export//i;
					}
					$saveout=1;
					$sth = $dbh->prepare($tmp) or die "Cannot prepare $tmp: $dbh->errstr/n";
					$sth->execute() or die "Cannot execute the query: $sth->errstr";
				}
				
				#�ж����ǰ��û��"--insert"ע�ͣ��оͲ���ָ��������ͽ�ִ�����
				elsif($tmp=~s/-{2,}insert (\S+) select//i)
				{
					$iname=$1;
					$iname=~s/\s+//g;

					#��iname�е��û����ͱ����ֿ���
					my @iname_array=split(/\./, $iname);
					
					#�жϴ�����ı��Ƿ���ڣ������ھ���create table������alter table����source_user�ֶΣ�������insert
					my $hastable="select * from all_tables where owner=\'$iname_array[0]\' and table_name=\'$iname_array[1]\'";
					$sth = $dbh->prepare($hastable) or die "Cannot prepare $tmp: $dbh->errstr/n";
					$sth->execute() or die "Cannot execute the query: $sth->errstr";
					if(!$sth->fetchrow_array())
					{
						$tmp="create table $iname as select \'$user_name\' source_user, ".$tmp;
						$sth = $dbh->prepare($tmp) or die "Cannot prepare $tmp: $dbh->errstr/n";
						$sth->execute() or die "Cannot execute the query: $sth->errstr";
						my $alt="alter table $iname modify (source_user char(30))";
						my $sth2 = $dbh->prepare($alt) or die "Cannot prepare $alt: $dbh->errstr/n";
						$sth2->execute() or die "Cannot alter the table structure: $sth2->errstr";
					}
					else
					{
						$tmp="insert into $iname select \'$user_name\' source_user, ".$tmp;
						$sth = $dbh->prepare($tmp) or die "Cannot prepare $tmp: $dbh->errstr/n";
						$sth->execute() or die "Cannot execute the query: $sth->errstr";
					}
					$saveout=0;
				}
				else
				{
					$saveout=0;
					$sth = $dbh->prepare($tmp) or die "Cannot prepare $tmp: $dbh->errstr/n";
					$sth->execute() or die "Cannot execute the query: $sth->errstr";
				}

				if($saveout)
				{
					#����ִ�е���ΪCSV�Ĳ����������ж�--export����û�б���������оͰ�$tname��Ϊ��׺��������$count����׺
					my $csvpath='';
					if($tname)
					{
						$csvpath="$dmp_dir/$user_name"."_$tname.csv";
					}
					else
					{
						$csvpath="$dmp_dir/$user_name"."_$count.csv";
						$count++;
					}
					open OUT, ">$csvpath" or die "Cannot open the csv file to write!";
					my $fields = join(',', @{ $sth->{NAME_lc} });
					print OUT "$fields\n";
					while (my @row = $sth->fetchrow_array()) {
						@row = map { defined $_? $_ : "NULL" } @row;  #�ѿ��ֶ�ת����NULL
						print OUT join(",", @row), "\n";
					}
					close OUT;
				}
			}
			$dbh->disconnect or warn "DB disconnect failed: $DBI::errstr\n";
		}
		
		# �ж�����--duѡ�����ɾ���û����û�������Ͳ�ɾ��
		if($deluser)
		{
			open DU, ">du.sql" or die "Cannot open the sql file to write!";
			print DU "drop user $user_name cascade;\n";
			print DU "exit;\n";
			close DU;
			system("sqlplus sys/$syspass\@$sid as sysdba \@du.sql")==0 or die "Cannot execute user deletion command.";
		}
		
		$timestamp=localtime;
		print LOG "��ɴ���$dmpfile��ʱ����$timestamp.\n";
		print LOG '-'x30, "\n";
		LOG->flush();
	} # End foreach
	$timestamp=localtime;
	print LOG "���ȫ������������$filenum���ļ�.\n";
	print LOG '='x30, "\n";
	close LOG;
	$mw->messageBox(-title => CT("���"), -message=>CT("������ɣ�"), -type=>'Ok', -icon=>'info');
}