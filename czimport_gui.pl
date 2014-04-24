use strict;
use Encode;
use Tk;
use Tk::BrowseEntry;
use File::Find;
use FileHandle;
use File::Path qw(make_path);
use DBI;
use CZImporthelper;

# 设定下面变量的缺省值，它们的值都可以通过命令行参数来修改
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
  
my @dmpfiles;                           #此数组存放所有待导入dmp文件名
my @statements;                         #此数组存放从SQL文件中读入的语句my $dir='';

# 下面创建主窗口，禁止其resize，并创建字体以供使用
my $mw = Tk::MainWindow->new;
$mw->resizable(0,0);                    
$mw->geometry("550x450+100+100");
$mw->title(CT("欢迎使用CZImport！"));
my $code_font = $mw->fontCreate('code', -family => 'Microsoft Yahei', -size => 11);

$mw->Label(-text=>CT("请输入Oracle服务器所在的主机名：*"), -font=>$code_font)->place(-x=>10, -y=>10);
$mw->Entry(-relief=>'sunken', -width =>18, -font=>$code_font, -textvariable => \$hostname)->place(-x=>10, -y=>35);

$mw->Label(-text=>CT("请输入Oracle服务器所在的SID：*"), -font=>$code_font)->place(-x=>300, -y=>10);
$mw->Entry(-relief=>'sunken', -width =>18, -font=>$code_font, -textvariable => \$sid)->place(-x=>300, -y=>35);

$mw->Label(-text=>CT("请输入sys用户的密码：*"), -font=>$code_font)->place(-x=>10, -y=>60);
$mw->Entry(-relief=>'sunken', -width =>18, -font=>$code_font, -textvariable => \$syspass)->place(-x=>10, -y=>85);

$mw->Label(-text=>CT("请输入导入数据的表空间名：*"), -font=>$code_font)->place(-x=>300, -y=>60);
$mw->Entry(-relief=>'sunken', -width =>18, -font=>$code_font, -textvariable => \$tbs)->place(-x=>300, -y=>85);

$mw->Label(-text=>CT("请选择dmp文件所在的文件夹：*"), -font=>$code_font)->place(-x=>10, -y=>115);
$mw->Entry(-relief=>'sunken', -width =>42, -state=>'disabled', -font=>$code_font, -textvariable => \$directory)->place(-x=>10, -y=>140);
$mw->Button(-text => CT("浏览"), -font=>$code_font, -anchor=>'n', -command => sub {$directory = CT($mw->chooseDirectory(-initialdir => '~', -title => CT('请选择一个目录')))})->place(-x=>400, -y=>135);

$mw->Label(-text=>CT("请选择待执行的SQL脚本："), -font=>$code_font)->place(-x=>10, -y=>170);
$mw->Entry(-relief=>'sunken', -width =>42, -state=>'disabled', -font=>$code_font, -textvariable => \$filepath)->place(-x=>10, -y=>200);
$mw->Button(-text => CT("浏览"), -font=>$code_font, -anchor=>'n', -command => \&Open_Sqlfile)->place(-x=>400, -y=>195);

$mw->Label(-text=>CT("请指定要导入的表，用逗号分隔（默认为所有表）："), -font=>$code_font)->place(-x=>10, -y=>230);
my $t=$mw->Scrolled("Text", -scrollbars => 'oe', -width=>50, -height=>4, -font=>$code_font)->place(-x=>10, -y=>260);
$mw->Checkbutton(-text => CT('使用完成后删除用户和表'), -variable => \$deluser, -font=>$code_font)->place(-x=>10, -y=>350);
$mw->Checkbutton(-text => CT('重建统计信息'), -variable => \$restats, -font=>$code_font)->place(-x=>300, -y=>350);

$mw->Button(-text => CT("开始！"), -command => \&ParseCommand, -font=>$code_font, -width=>10)->place(-x=>120, -y=>400);
$mw->Button(-text => CT("退出"), -command => sub { exit }, -font=>$code_font, -width=>10)->place(-x=>260, -y=>400);

Tk::MainLoop();

###################################################
#    CT函数，用来对中文字符进行Decode，防止乱码          #
###################################################
sub CT
{
	my $str = shift @_;
	return decode("gb2312", $str);
}

#######################################################
#    Open_Sqlfile函数，用来弹出打开文件的对话框，选择SQL脚本  #
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
#    AddDumpFiles函数，主要供File::Find使用，有--dir       #
#    选项的时候，则递归搜索指定的目录，把找到的dmp文件加         #
#    入@dmpfiles数组                                    #
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
#    ParseCommand函数，检查输入参数是否正确              #
#    如果不正确，则弹出报错提示，否则就执行ImportFile函数   #
#####################################################
sub ParseCommand
{
    if(!$directory)
    {
        $mw->messageBox(-title => CT("出错啦！"), -message=>CT("请指定dmp文件所在目录！"), -type=>'Ok', -icon=>'error');
        return 1;
    }
    if(!$hostname)
    {
        $mw->messageBox(-title => CT("出错啦！"), -message=>CT("请输入主机名！"), -type=>'Ok', -icon=>'error');
        return 1;
    }
    if(!$sid)
    {
        $mw->messageBox(-title => CT("出错啦！"), -message=>CT("请输入SID！"), -type=>'Ok', -icon=>'error');
        return 1;
    }
    if(!$syspass)
    {
        $mw->messageBox(-title => CT("出错啦！"), -message=>CT("请输入sys用户的密码！"), -type=>'Ok', -icon=>'error');
        return 1;
    }
    if(!$tbs)
    {
        $mw->messageBox(-title => CT("出错啦！"), -message=>CT("请输入表空间名称！"), -type=>'Ok', -icon=>'error');
        return 1;
    }
    
    $dirs = encode("gb2312", $directory);
    $sqlfilepath = encode("gb2312", $filepath);
    
    find(\&AddDumpFiles, $dirs);
    
    #如果路径下没有任何文件，则报错退出。
	if(@dmpfiles==0)
	{
        $mw->messageBox(-title => CT("出错啦！"), -message=>CT("指定目录下没有dmp文件！"), -type=>'Ok', -icon=>'error');
		return 1;
	}
		
	&ImportFile();
}

#############################################################
#    ImportFile函数，功能是将给定的dmp文件逐个导入数据库。          #
#    导入的时候会根据dmp文件的basename，建立同名用户，              #
#    密码与用户名相同。该函数会生成cu.sql文件，并调用SQLPlus        #
#    来执行创建用户和授权功能，最后调用imp导入数据。                 #
#############################################################
sub ImportFile
{
    my $filenum=0;                #用于统计处理的文件数
	my $timestamp=localtime;      #用于获取时间
    open LOG, ">importlog.txt" or die "Cannot open log file to write!";
	print LOG "开始运行czimport程序, 时间是$timestamp.\n";
	print LOG '='x30, "\n";

	#下面判断用户有无指定sql脚本文件，有则读入内容并分解为多个SQL语句
	if($sqlfilepath)
	{
		@statements=&ParseSQL($sqlfilepath);
    }
    
    #下面遍历每个dmp文件，进行导入操作
	foreach my $dmpfile (@dmpfiles)
	{
		my ($user_name, $dmp_dir)=&GetUserName($dmpfile);
		# 下面建立一个cu.sql的文件，把建立用户和授权的SQL语句写进去，用sqlplus执行
		open CU, ">cu.sql" or die "Cannot open the sql file to write!";
		print CU "create user $user_name identified by $user_name default tablespace $tbs account unlock;\n";
		print CU "grant CONNECT to $user_name WITH ADMIN OPTION;\n";
		print CU "grant RESOURCE to $user_name WITH ADMIN OPTION;\n";
		print CU "grant DBA to $user_name WITH ADMIN OPTION;\n";
		print CU "exit;\n";
		close CU;
		system("sqlplus sys/$syspass\@$sid as sysdba \@cu.sql")==0 or die "Cannot execute user creation command.";
		$timestamp=localtime;
		print LOG "开始导入$dmpfile，时间是$timestamp.\n";

		#判断有无--tables选项，有则导入指定表，否则导入全部表
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
		print LOG "结束导入$dmpfile, 时间是$timestamp.\n";
		$filenum++;
	
	    #下面判断用户有无指定sql脚本文件，有则连接数据库执行sql脚本
		if($sqlfilepath)
		{
			#连接数据库并让数据库不区分大小写
			my $dbh=DBI->connect("dbi:Oracle:host=$hostname;sid=$sid", $user_name, $user_name) or die "Cannot conenct db: $DBI::errstr\n";
			my $case_insensitive_sth1=$dbh->prepare("ALTER SESSION SET NLS_COMP=ANSI");
			my $case_insensitive_sth2=$dbh->prepare("ALTER SESSION SET NLS_SORT=BINARY_CI");
			$case_insensitive_sth1->execute() or die "Cannot execute the query: $case_insensitive_sth1->errstr";
			$case_insensitive_sth2->execute() or die "Cannot execute the query: $case_insensitive_sth2->errstr";
			
			#判断是否要重建统计信息
            if($restats)
            {
                $dbh->do("begin\n dbms_stats.gather_schema_stats(\'$user_name\',estimate_percent=>100,cascade=> TRUE);\nEND;");
            }
			
			# 下面逐条执行从文件中读取的SQL语句，将结果存在“dmp文件名_计数.csv“文件中
			my $count=1;
			my $tname='';          #export后面跟的表名
			my $iname='';          #insert后面跟的表名
			my $saveout=0;         #判断是否保存为CSV
			my $insertdata=0;      #判断是否插入数据库
			my $tmp;
			foreach my $statement (@statements)
			{
				$tmp=$statement;
				my $sth;
				
				#判断语句前有没有"--export"注释，有就保存为CSV文件，否则就仅执行语句
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
				
				#判断语句前有没有"--insert"注释，有就插入指定表，否则就仅执行语句
				elsif($tmp=~s/-{2,}insert (\S+) select//i)
				{
					$iname=$1;
					$iname=~s/\s+//g;

					#把iname中的用户名和表名分开来
					my @iname_array=split(/\./, $iname);
					
					#判断待插入的表是否存在，不存在就用create table创建并alter table加入source_user字段，存在则insert
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
					#下面执行导出为CSV的操作，首先判断--export后有没有表名，如果有就把$tname作为后缀，否则用$count作后缀
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
						@row = map { defined $_? $_ : "NULL" } @row;  #把空字段转化成NULL
						print OUT join(",", @row), "\n";
					}
					close OUT;
				}
			}
			$dbh->disconnect or warn "DB disconnect failed: $DBI::errstr\n";
		}
		
		# 判断有无--du选项，有则删除用户和用户表，否则就不删除
		if($deluser)
		{
			open DU, ">du.sql" or die "Cannot open the sql file to write!";
			print DU "drop user $user_name cascade;\n";
			print DU "exit;\n";
			close DU;
			system("sqlplus sys/$syspass\@$sid as sysdba \@du.sql")==0 or die "Cannot execute user deletion command.";
		}
		
		$timestamp=localtime;
		print LOG "完成处理$dmpfile，时间是$timestamp.\n";
		print LOG '-'x30, "\n";
		LOG->flush();
	} # End foreach
	$timestamp=localtime;
	print LOG "完成全部处理，共处理$filenum个文件.\n";
	print LOG '='x30, "\n";
	close LOG;
	$mw->messageBox(-title => CT("完成"), -message=>CT("操作完成！"), -type=>'Ok', -icon=>'info');
}