============================
MergeCSVʹ��˵��
============================

һ�����
-----------

mergecsv�������ϲ�����ṹ��ͬ��csv�ļ���С���򣬲���Perl����


����ʹ�÷���
--------------

1. ���иó����ã� ::

	perl mergecsv.pl [ѡ��]
	
2. ѡ�����£� ::

	--dir=    ָ��csv���ڵ��ļ���Ŀ¼�����Ŀ¼֮���ö��ŷֿ�[����]
	--of=     ָ������Ļ���csv���ļ�����ȱʡ��mergecsv.pl����Ŀ¼��mergeresult.csv
	--log=    ָ������csv����־�ļ����ļ�����ȱʡ��mergecsv.pl����Ŀ¼��mergecsv_log.txt
	--tn=     ָ�������ܵ�csv�ļ��ı�����׺�����ڵ�����csv���ǡ��û���_����.csv�������Ҫ����ָ�������Ҫָ��--tn�������ָ�����������csv�ļ���
	
3. ʹ�þ����� ::

	perl mergecsv.pl --dir=d:/result
	��D��resultĿ¼�µ�csv�ļ�ȫ�����ܣ����ɵĻ����ļ�����־�ļ�������mergecsv.pl���ڵ�Ŀ¼��
	perl mergecsv.pl --dir=d:/result --of=c:/sum.csv --log=c:/log.txt
	��D��resultĿ¼�µ�csv�ļ�ȫ�����ܣ�����sum.csv�����ļ���log.txt��־�ļ���������C�̸�Ŀ¼��
	perl mergecsv.pl --dir=d:/result --tn=kemu_three
	��D��resultĿ¼�����������ǡ�kemu_three����β�ı���ܣ����ɵĻ����ļ�����־�ļ�������mergecsv.pl���ڵ�Ŀ¼��

===========
The End
===========