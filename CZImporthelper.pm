package CZImporthelper;
use strict;
use File::Basename;
require Exporter;

our @ISA=qw(Exporter);

our @EXPORT=qw(ParseSQL DisplayHelp GetUserName);

#######################################################
#    DisplayHelp函数：如果有--help选项，则显示帮助信息      #
#######################################################
sub DisplayHelp
{
	print "szimport程序是由审计署成都办计算机出开发的Perl小程序。\n";
	print "其用途是把若干个Oracle dmp文件批量导入数据库并执行查询。\n";
	print "版权没有，盗版不究。您可以随意修改源代码。\n";
	print "用法：perl szimport.pl [参数]\n";
	print "参数有：\n";
	print "  --syspass=    the password of the sys user in Oracle.\n";
	print "  --tbs=        the tablespace to use for imp.\n";
	print "  --host=       the hostname of the Oracle server.\n";
	print "  --sid=        the Oracle sid.\n";
	print "  --file=       comma seperated file patterns to specify the files to be imported.\n";
	print "  --dir=        comma seperated directories in which dmp files reside(recursively).\n";
	print "  --outdir=     the directory to hold the result csv files.\n";
	print "  --tables=     comma seperated table names to be import.\n";
	print "  --sql=        the sql script to be executed after importing the data.\n";
	print "  --log=        the path of the log file.\n";
	print "  --du          delete the user the tables belongs to him at last.\n";
}

########################################################
#    ParseSQL函数：用于读取给定的SQL脚本并把它分解为一条条   # 
#    语句，放入数组后返回。                               #
#    输入： SQL脚本路径                                  #
#    输出： 一个数组，按分号将脚本分开为一条条语句           #
########################################################

sub ParseSQL
{
	my $fpath=shift @_;
	my $tmp='';       #用于临时存放语句
	my @queries;      #用于存放结果返回
	# 打开待执行的SQL语句所在的文件，读入其内容到一个标量中
	open SQL, "<$fpath" or die "Cannot open the SQL statement file.";
	while(<SQL>)
	{
		#去掉结尾的换行符，首尾的白空格和多余的白空格
		chomp;
		s/^\s+//;
		s/\s+$//;
		s/\s+/ /g;

		#如果不是空行，则表明是语句或注释
		if($_)
		{
	        #判断是否为--export或--insert注释，如果是则保留这行，如果为其他注释，则删除这行
			if(/^-{2,}(\S+)/)
			{
				if(($1=~/export/i) or ($1=~/insert/i))
				{
					$tmp=$tmp.$_;
				}
				else
				{
					$_='';
				}
			}
			else
			{
				$tmp=$tmp." $_";
				if(/;$/)
				{
					$tmp=~s/^\s+//;
					$tmp=~s/;//;
					push @queries, $tmp;
					$tmp='';
				}
			}
		}
	}
	close SQL;
	return @queries;
}

#############################################################
#    GetUserName函数，根据文件名取其basename作为要建立的        #
#    用户名，还取出其所在目录                                  #
#    输入：一个代表文件全路径的字符串                           #
#    返回：文件的basename和dirname                            #
#############################################################
sub GetUserName
{
	my ($uname, $dmpdir)=fileparse(shift @_, qr/\.(\w+)$/);
	return ($uname, $dmpdir);
}

1;



