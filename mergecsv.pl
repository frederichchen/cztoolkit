use strict;
use File::Basename;
use File::Find;
use File::Path qw(make_path);
use Getopt::Long;

my $dirs='';
my $outfile='';
my $logfile='';
my $tname='';
my $help='';

my @csvfiles;

########################################################
#    AddCSVFiles函数，主要供File::Find使用，有--dir       #
#    选项的时候，则递归搜索指定的目录，把找到的csv文件加         #
#    入@csvfiles数组                                    #
########################################################
sub AddCSVFiles
{
	if (-f $File::Find::name) {
        if ($File::Find::name =~ /$tname\.csv$/) {
            push @csvfiles, $File::Find::name;
        }
	}
}

#############################################################
#    GetUserName函数，根据文件名取其basename作为要建立的        #
#    用户名，还取出其所在目录                                  #
#    输入：一个代表文件全路径的字符串                           #
#    返回：文件的basename和dirname                            #
#############################################################
sub GetUserName
{
	my ($uname, $csvdir)=fileparse(shift @_, qr/\.(\w+)$/);
	return ($uname, $csvdir);
}

#######################################################
#    DisplayHelp函数：如果有--help选项，则显示帮助信息      #
#######################################################
sub DisplayHelp
{
	print "mergecsv程序是由审计署成都办计算机出开发的Perl小程序。\n";
	print "其用途是把若干个结构相同的csv文件批量合并为一个。\n";
	print "版权没有，盗版不究。您可以随意修改源代码。\n";
	print "用法：perl mergecsv.pl [参数]\n";
	print "参数有：\n";
	print "  --dir=        comma seperated directories in which csv files reside(recursively).\n";
	print "  --of=         the path of the final result csv file.\n";
	print "  --tn=         the table name suffix of the csv file.\n";
	print "  --log=        the path of the merge log file.\n";
}

#############################################################
#    ParseCommand函数：分析命令行参数并调用相应的函数              #
#############################################################
sub ParseCommand
{
	my $result=GetOptions(
		'dir=s' => \$dirs,
		'of=s' => \$outfile,
		'log=s' => \$logfile,
		'tn=s'  => \$tname,
		'help!' => \$help);
	
	# 遇到无法解析的参数则直接报错退出
	if(!$result) 
	{
		exit(1);
	}
	
	#如果有--help，则显示帮助信息
	if($help)
	{
		&DisplayHelp();
		exit(0);
	}
	
	# 如果指定多个目录，则递归查找其中的csv文件
	if($dirs)
	{
	    $dirs=~s/\\/\//g;
	    foreach my $dir (split(/,/, $dirs))
		{
			find(\&AddCSVFiles, $dir);
		}
	}
	
	# 如果没有找到CSV文件则报错退出
	if(@csvfiles==0)
	{
		print "Cannot find csv files to merge.\n";
		print "For command line usage help, please execute with --help option.\n";
		exit(1);
	}
	
	# 如果未指定日志文件，则默认在mergecsv.pl所在文件夹中建立'mergecsv_log.txt'
	if(!$logfile)
	{
		$logfile='mergecsv_log.txt';
	}
	else
	{
		$logfile=~s/\\/\//g;
		my ($base, $dir)=&GetUserName($logfile);
		if(!-e $dir)
		{
			make_path($dir);
		}
	}
	
	# 如果未指定结果输出文件，则默认在mergecsv.pl所在文件夹中建立'mergeresult.csv'
	if(!$outfile)
	{
		$outfile='mergeresult.csv';
	}
	else
	{
		$outfile=~s/\\/\//g;
		my ($base, $dir)=&GetUserName($outfile);
		if(!-e $dir)
		{
			make_path($dir);
		}
	}
	&MergeCSV();
}

#######################################################
#    MergeCSV: 主程序，遍历指定的csv文件，合并记录并生成日志  #
#    如果遇到结构不同的CSV则跳过                           #
#######################################################

sub MergeCSV
{
	open LOG, ">$logfile" or die "Cannot open log file to write!";
	open RESULT, ">$outfile" or die "Cannot open result file to write!";
	my $timestamp=localtime;
	my $headers;
	my $rightfilenum=0;
	my $wrongfilenum=0;
	print LOG "开始合并，时间是$timestamp.\n";
	print LOG '='x30, "\n";
	foreach my $csvfile (@csvfiles)
	{
		my $rowcount=1;
		my ($filesource,$filedir)=&GetUserName($csvfile);
		$filesource=~s/_$tname$//;
		if(!open DATA, "<$csvfile")
		{
			warn "Cannot open $csvfile, skip that file!";
			print LOG "无法打开$csvfile, 跳过……\n";
			print LOG '-'x30, "\n";
			$wrongfilenum++;
		}
		else
		{
			$timestamp=localtime;
			print LOG "开始处理$csvfile，时间是$timestamp.\n";
			if(!$headers)
			{
				$headers=<DATA>;
				chomp($headers);
				print RESULT "来源表,$headers\n";
				$rowcount++;
				while(<DATA>)
				{
					chomp;
					print RESULT "$filesource,$_\n";
					$rowcount++;
				}
				$timestamp=localtime;
				print LOG "完成，共处理$rowcount行，时间是$timestamp.\n";
				print LOG '-'x30, "\n";
				$rightfilenum++;
			}
			else
			{
				my $tmp=<DATA>;
				chomp($tmp);
				if($headers ne $tmp)
				{
					print LOG "$csvfile文件头与其它文件不匹配，跳过……\n";
					print LOG '-'x30, "\n";
					$wrongfilenum++;
				}
				else
				{
					while(<DATA>)
					{
						chomp;
						print RESULT "$filesource,$_\n";
						$rowcount++;
					}
					print LOG "完成，共处理$rowcount行，时间是$timestamp.\n";
					print LOG '-'x30, "\n";
					$rightfilenum++;
				}
			}
		close DATA;
		}
	}
	print LOG "完成合并，共合并$rightfilenum个文件，跳过$wrongfilenum个文件。\n";
	print LOG '='x30;
	close LOG;
	close RESULT;
}

&ParseCommand();