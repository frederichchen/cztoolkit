==========================
批量导入程序使用指南
==========================

一、简介
------------

czimport是用Perl开发的批量导入dmp文件，执行给定查询并将结果导出成csv文件的小程序，程序包含czimport.pl、CZImporthelper.pm两个文件。


二、使用方法
----------------

1. 把czimport.pl和CZImporthelper.pm两个文件放到任何用户指定目录，把Perl的可执行程序加入PATH（如果是在Windows下安装的Oracle 11g，可以在其安装目录下找到Perl，将其加入PATH环境变量，例如X:\App\Administrator\product\11.2.0\dbhome_1\perl\bin）。在Windows下建议直接安装ActivePerl或者Strawberry Perl。
2. 在Oracle中建立一个足够大的表空间。
3. 建立一个待执行的SQL语句的文件，文件中可以有多条SQL语句，语句间用分号分隔，要导出为csv的语句前加上--export注释，export后面可以跟一个表名。例如：--export 科目表
4. 使用方法： ::

	perl czimport.pl [选项]
	选项有：
	--syspass=SYS用户密码，默认是yourpass
	--tbs=要导入数据的表空间，默认是sccz
	--host=Oracle所在的主机名，默认是localhost
	--sid=Oracle的SID，默认是orcl
	--file=要导入的dmp文件，多个文件用逗号分隔，支持通配符
	--dir=要导入的dmp文件所在的文件夹，多个文件夹用逗号分隔
	--outdir=指定输出的csv文件存放的文件夹，如不指定则csv放在对应的dmp所在的文件夹内
	--tables=要导入的表名，对应Oracle imp的tables选项，表名之间用逗号分隔
	--sql=要执行的查询脚本，默认是空，即不执行查询
	--log=日志文件的存放路径，默认是与czimport.pl同目录下的importlog.txt
	--du  如果设置这个选项，则导入数据执行完查询后将删除用户和用户表，默认不删除

5. 程序运行结果生成的csv文件会放在--outdir指定的文件夹内，如果没有指定，则会放在对应的dmp文件所在的文件夹内。如果--export后指定有表名，则导出的文件名会是“用户名_表名.csv”；如果没有指定表名，则导出的文件名会是“用户名_计数器.csv”。


三、使用举例
-----------------

::
	perl czimport.pl --syspass=mypass --tbs=mytbs --sid=orcl --file=/dir/of/dmp/*.dmp --sql=/path/to/sql --du
	导入/dir/of/dmp/目录下的所有dmp文件到本机的Oracle数据库，执行sql语句，完成后删除用户和表
	perl czimport.pl --file=file1.dmp, /dir/of/dmp/*.dmp
	导入czimport.pl所在目录下的file1.dmp和/dir/of/dmp/目录下的所有dmp文件到本机的Oracle数据库
	perl czimport.pl --syspass=mypass --dir=e:/dmps --outdir=e:/result --tables=a,b,c
	导入e:/dmps目录下的所有dmp文件的a、b、c三张表，输出结果CSV到e:/result目录。


四、程序运行流程简介
-----------------------

该程序会首先找出指定的dmp文件，然后根据其文件名建立一个用户名和密码都与文件名相同的用户并指定其表空间，然后调用Oracle的imp程序进行数据导入；导入完成后会依次运行用户给定的.sql文件中的查询，并把查询结果保存成CSV文件，完成查询后如果有--du选项则删除建立的用户和用户下面的所有表。



==============
The End
==============
