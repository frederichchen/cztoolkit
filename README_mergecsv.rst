============================
MergeCSV使用说明
============================

一、简介
-----------

mergecsv是用来合并多个结构相同的csv文件的小程序，采用Perl开发


二、使用方法
--------------

1. 运行该程序用： ::

	perl mergecsv.pl [选项]
	
2. 选项如下： ::

	--dir=    指定csv所在的文件的目录，多个目录之间用逗号分开[必须]
	--of=     指定输出的汇总csv的文件名，缺省是mergecsv.pl所在目录的mergeresult.csv
	--log=    指定汇总csv的日志文件的文件名，缺省是mergecsv.pl所在目录的mergecsv_log.txt
	--tn=     指定待汇总的csv文件的表名后缀，由于导出的csv都是“用户名_表名.csv”，因此要汇总指定表就需要指定--tn。如果不指定则汇总所有csv文件。
	
3. 使用举例： ::

	perl mergecsv.pl --dir=d:/result
	将D盘result目录下的csv文件全部汇总，生成的汇总文件和日志文件均放在mergecsv.pl所在的目录中
	perl mergecsv.pl --dir=d:/result --of=c:/sum.csv --log=c:/log.txt
	将D盘result目录下的csv文件全部汇总，生成sum.csv汇总文件和log.txt日志文件，都放在C盘根目录下
	perl mergecsv.pl --dir=d:/result --tn=kemu_three
	将D盘result目录下所有名称是“kemu_three”结尾的表汇总，生成的汇总文件和日志文件均放在mergecsv.pl所在的目录中

===========
The End
===========