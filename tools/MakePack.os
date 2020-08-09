Перем ЗаписьXML, ЗаписьZIP, КаталогСкрипта, КаталогПакета, СуффиксВерсии;

Процедура ДобавитьЭлемент(Система, Архитектура, ИмяФайла)

	Файл = новый Файл(ИмяФайла);
	НовоеИмяФайла = Сред(Файл.ИмяБезРасширения, 4) + СуффиксВерсии + Файл.Расширение;

	ЗаписьXML.ЗаписатьНачалоЭлемента("component");
	ЗаписьXML.ЗаписатьАтрибут("type", "native");
	ЗаписьXML.ЗаписатьАтрибут("os", Система);
	ЗаписьXML.ЗаписатьАтрибут("arch", Архитектура);
	ЗаписьXML.ЗаписатьАтрибут("path", НовоеИмяФайла);
	ЗаписьXML.ЗаписатьКонецЭлемента();

	КопироватьФайл(КаталогСкрипта + "/" + ИмяФайла, КаталогПакета + НовоеИмяФайла);
	ЗаписьZIP.Добавить(КаталогПакета + НовоеИмяФайла, РежимСохраненияПутейZIP.НеСохранятьПути);
	
КонецПроцедуры

Процедура MakePackage()

	КаталогСкрипта = ТекущийСценарий().Каталог + "/..";
	КаталогПакета = КаталогСкрипта + "/bin/";
	СоздатьКаталог(КаталогПакета);

	НомерВерсии = ""; 
	СуффиксВерсии = "";
	ТекстовыйДокумент = Новый ТекстовыйДокумент;
	ТекстовыйДокумент.Прочитать(КаталогСкрипта + "/src/version.h");
	Для НомерСтроки = 1 по 4 Цикл 
		Стр = ТекстовыйДокумент.ПолучитьСтроку(НомерСтроки);
		Если НомерСтроки > 1 Тогда НомерВерсии = НомерВерсии + "."; КонецЕсли;
		НаборСтрок = СтрРазделить(СтрЗаменить(Стр, Символы.Таб, " "), " ", Ложь);
		ЭлементВерсии = НаборСтрок.Получить(НаборСтрок.Количество() - 1);
		СуффиксВерсии = СуффиксВерсии + "_" + ЭлементВерсии;
		НомерВерсии = НомерВерсии + ЭлементВерсии;
	КонецЦикла;

	Сообщить("Номер версии: " + НомерВерсии);	

	ИмяПакета = КаталогСкрипта + "/AddIn.zip";
	ИмяФайла = КаталогПакета + "MANIFEST.XML";

	УдалитьФайлы(ИмяПакета);
	ЗаписьZIP = Новый ЗаписьZipФайла(ИмяПакета); 

	ЗаписьXML = Новый ЗаписьXML;
	ЗаписьXML.ОткрытьФайл(ИмяФайла, "UTF-8", Истина);
	ЗаписьXML.ЗаписатьБезОбработки("<?xml version=""1.0"" encoding=""UTF-8""?>");	
	ЗаписьXML.ЗаписатьНачалоЭлемента("bundle");	
	ЗаписьXML.ЗаписатьАтрибут("xmlns", "http://v8.1c.ru/8.2/addin/bundle");
	
	ДобавитьЭлемент("Windows" , "i386"   , "bin32/libGitFor1cWin32.dll");
	ДобавитьЭлемент("Windows" , "x86_64" , "bin64/libGitFor1cWin64.dll");
//	ДобавитьЭлемент("Linux"   , "i386"   , "bin/libGitFor1cLin32.so");
//	ДобавитьЭлемент("Linux"   , "x86_64" , "bin/libGitFor1cLin64.so");
	
	ЗаписьXML.ЗаписатьКонецЭлемента();
	ЗаписьXML.Закрыть();
	
	ЗаписьZIP.Добавить(ИмяФайла, РежимСохраненияПутейZIP.НеСохранятьПути);
	ЗаписьZIP.Записать();

КонецПроцедуры

MakePackage();