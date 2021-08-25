#%%

import pandas as pd
import re
import phonenumbers
from phonenumbers import geocoder
from functools import wraps
from typing import Union, Any, List


#%%
# Задача: выделить из клиентской базы русскоязычных клиентов, подготовить номера, разделить на группы для рассылки
# Колонки: Имя, Номер телефона, Email, Национальность/Страна/Язык
# Данные:
# - Разделены на несколько файлов по годам, из-за чего возможны дубли;
# - В разных файлах колонки могут иметь разные названия, и находятся в разном порядке;
# - У одной записи может быть несколько номеров телефонов;
# - Некоторые номера могут быть невалидными;
# - В колонке Национальность неконсистентная запись значений - кроме национальности могут быть указана страна или язык,
# названия могут указываться с ошибками или в разном формате


# %%
# Чтение и подготовка данных к работе

def _print_func_execution(fn):
    """
    Декоратор.
    Получает на вход функцию.
    Печатает строку с названием функции, формат: "function_name - DONE"
    """

    @wraps(fn)
    def wrapper(*args, **kwargs):
        result = fn(*args, **kwargs)
        print(f"{fn.__name__} - DONE")
        return result

    return wrapper

@_print_func_execution
def read_excel(file_path: str, file_name: str) -> pd.DataFrame:
    """
    Функция читает excel файл, сохраняет в формате датафрейм пандас.

    :param file_path: str
    :param file_name: str
    :return: pd.DataFrame
    """
    df = pd.read_excel(f'{file_path}{file_name}.xlsx')
    return df


@_print_func_execution
def add_year(df: pd.DataFrame, year: str) -> pd.DataFrame:
    """
    Добавляет столбец с годом в датафрейм.
    1 датафрейм - 1 год.

    :param df: pd.DataFrame
    :param year: str
    :return: pd.DataFrame
    """
    df['year'] = year
    return df


@_print_func_execution
def columns_standartization(df: pd.DataFrame, column_names: List[str]) -> pd.DataFrame:
    """
    Переименовывает колонки датафрейма. \n
    1. Приводит колонки датафрейма к нижнему регистру.
    2. С помощью регулярного выражения находит соответсвующую колонку и переименовывает.
    3. Меняет порядок колонок, указанные в переданном параметре column_names

    :param df: pd.DataFrame
    :param column_names: List[str]
    :return: pd.DataFrame
    """
    df.columns = map(str.lower, df.columns)

    df.rename(columns={
        df.filter(regex=("phone|mobile")).columns.to_list()[0]: 'phone',
        df.filter(regex=("name")).columns.to_list()[0]: 'name',
        df.filter(regex=("email")).columns.to_list()[0]: 'email',
        df.filter(regex=("nat")).columns.to_list()[0]: 'nationality',
    }, inplace=True)

    clients = df[column_names]

    return clients


@_print_func_execution
def join_df(df: pd.DataFrame, united_df: pd.DataFrame) -> pd.DataFrame:
    """
    Принимает на вход два датафрейма.
    Добавляет (append) все строки первого датафрейма ко второму.

    :param df: pd.DataFrame
    :param all_clients: pd.DataFrame
    :return: pd.DataFrame
    """
    united_df = united_df.append(df, ignore_index=True)
    return united_df


# %%
# Создаем вcпомогательные объекты для чтения файлов

# Список с названиями файлов, по которому будем итерироваться
years = [2012, 2013, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020]

# Пустой датафрейм в который потом будут добавляться (append) подготовленные датафремы
all_clients = pd.DataFrame(columns=['name', 'phone', 'email', 'nationality', 'year'])

# Список с правильными названиями колонок
columns = all_clients.columns.to_list()

# Путь к папке с файлами
files_path = 'leads_data/'


# %%
# Итерируемся по списку с годами
# Для каждого года находим соответствующий файл, читаем в датафрейм, приводим колонки к одному виду,
# добавляем к общему датафрейму

for year in years:
    print(year)
    all_clients = join_df(columns_standartization(add_year(read_excel(files_path, year), year), columns), all_clients)
    print('\n')  # разделитель для удобства вывода информации


# %%
# Смотрим на пропуски в данных
all_clients.info()

# В данных очень много пропусков.
# В данный момент нам нужны данные только для русскоговорящих клиентов,
# посмотрим на пропуски соответствующих записей после фильтрации.


# %%
# Копируем датасет для сохранения изначальных данных
clients_df = all_clients.copy()


# %%
# Убираем дубликаты - по имени и номеру телефона
# Т.к. мы готовим данные для смс рассылки, нас не интересует email
clients_df.drop_duplicates(subset=['name', 'phone'], inplace=True)

# Убираем записи без номеров телефонов
clients_df.dropna(subset=['phone'], inplace=True)

# Обновляем индексы т.к. часть данных была удалена
clients_df.reset_index(drop=True, inplace=True)
clients_df.info()

# %%
#Работа с номерами телефонов

def multiple_str_to_list(df_row: pd.DataFrame, column_name: str, regex_pat: str) -> Union[str, List, pd.Series]:
    """
    Преобразует строку с несколькими номерами телефонов в список.
    На вход принимает датафрейм, построчно; название колонки, разделитель - регулярное выражение.
    Находит колонку с названием переданным в column_name.
    Если есть строка, разделяет с помощью regex_pat - возвращает список.
    Если записи нет - возвращает исходное значение.

    :param df_row: pd.DataFrame
    :param column_name: str
    :param regex_pat: str
    :return: List or pd.Series
    """
    try:
        phone_list = re.split(regex_pat, df_row[column_name])
        return phone_list
    except:
        return df_row['phone']


def phone_validator(phone_list: List[str]) -> Union[List[str], Any]:
    """
    Валидирует номера телефонов, используя библиотеку phonenumbers.
    На вход принимает список со строками, в которых должны содержаться номера телефонов.
    Если номер телефона валидный - добавляем в список valid.
    Если проверку произвести не удалось - возвращаем False

    :param phone_list: List[str]
    :return: List[str] or False
    """
    valid = []
    try:
        for ph in phone_list:
            phone = phonenumbers.parse(ph, None)
            if phonenumbers.is_possible_number(phone):
                valid.append(ph)
        return valid
    except:
        return phone_list


def phone_formatter(phone_list: List[str]) -> Union[str, List[str]]:
    """
    Форматирует номера телефонов согласно международному формату E164, используя библиотеку phonenumbers.
    На вход принимает список со строками, в которых содержатся номера телефонов.
    Если телефон валидный, форматирует согласно E164 и добавляет в список.
    Если форматирование не удалось, возвращает исходный список.

    :param phone_list: List[str]
    :return: Union[str, List[str]]
    """
    formatted = []
    # formatted_str = ''
    try:
        for ph in phone_list:
            phone = phonenumbers.format_number(phonenumbers.parse(ph, None), phonenumbers.PhoneNumberFormat.E164)
            formatted.append(phone)
        return formatted
    except:
        return phone_list


def get_country(phone_list: List[str]) -> Union[List[str], str]:
    """
    Определяет страну номера телефона, используя библиотеку phonenumbers.
    На вход принимает список строк с номерами телефонов.

    :param phone_list: List[str]
    :return: Union[List[str], str]
    """
    country = []
    try:
        for ph in phone_list:
            phone = phonenumbers.parse(ph, None)
            cntr = geocoder.description_for_number(phone, 'en')
            if len(cntr) == 0:
                cntr = 'unknown'
            country.append(cntr)
        return country
    except:
        return 'unknown'


# %%
# Парсим номера телефонов, сохраняя из строки в список, записываем в отдельную колонку
clients_df['phone_list'] = clients_df.apply(multiple_str_to_list, axis=1, args=('phone', ', |; '))

# Валидируем номера телефонов и записываем в отдельную колонку
clients_df['valid_phones'] = clients_df['phone_list'].apply(phone_validator)

# Форматируем номера телефонов согласно международному стандарту
clients_df['formatted_phones'] = clients_df['valid_phones'].apply(phone_formatter)

# Получаем страну номера телефона и записываем в отдельную колонку
clients_df['phone_country'] = clients_df['valid_phones'].apply(get_country)


#%%
# Для каждой записи, где есть несколько номеров телефона, нужно записать номер телефона и его страну в отдельную строку,
# продублировав остальную информацию.
# Функция Explode не работает с несколькими колонками сразу, поэтому колонки, которые нужно просто дублировать,
# запишем в индекс, а те, которые нужно "развернуть" передадим в explode, после восстановим индекс

clients_df_eploded = clients_df[['name', 'nationality', 'year', 'formatted_phones', 'phone_country']]\
    .set_index(['name', 'nationality', 'year']).apply(pd.Series.explode).reset_index()


#%%
# Выбор русскоязычной аудитории
# Нужно выбрать те записи, у которых либо номер телефона, либо информация в колонке nationality
# относится к русскоговорящим странам

# Смотрим все уникальные значения колонки nationality, записываем в отдельный список те,
# которые могут относиться к русскоговорящим странам
clients_df_eploded['nationality'].unique()
ru_nationalities = [
    'Russian', 'Russia', 'Kazakhstan', 'Ukraine', 'Russai', 'Russin',
    'Belarus', 'Yakutia', 'Rus/Germ', 'Ukrainian', 'Belarussian',
    'Rus/Ital', 'Buryatia', 'Kz', 'Ukr', 'Turkish/KZ', 'Kazakh', 'RU',
    'Russian ', 'russian (Serbia)', 'russian', 'Belorussia', 'Rusia',
    'rus', 'Rus', 'Russian, Australian', 'Russian and Italy ',
    'Russian/ turkish ', 'Ukr/Rus', 'Rissian', 'Rusian',  'Ukranian',
    'Russian (KZ)', 'Russsian', 'Belarussia', 'Russian(Japan)',
    'Russian(UZ)',  'Georgian', 'Kazan`', 'Rus/Korea', 'Latvia',
    'Rus/AUS', 'Kaz', 'Belarus ', 'Russain', 'Kazakhstan ',
    'Ukraine ', 'Russia ', 'Ucraine', 'Russian  '
]


#%%
# Смотрим все уникальные значения колонки phone_country, записываем в отдельный список те,
# которые могут относиться к русскоговорящим клиентам
clients_df_eploded['phone_country'].unique()
ru_nationalities = [
        'Russia', 'St Petersburg', 'Primorie territory', 'Kazakhstan', 'Ukraine', 'Tomsk', 'Belarus', 'Odesa'
]


# %%
# Фильтруем датасет с помощью полученных списков
ru_speaking = clients_df_eploded[
    (clients_df_eploded['phone_country'].isin(ru_nationalities)) |
    (clients_df_eploded['nationality'].isin(ru_nationalities))
    ]


#%%
# Обновим индекс, т.к. часть записей отфильтровали
ru_speaking.reset_index(drop=True, inplace=True)


#%%
# Разметка всех записей
# Разделим все записи на 7 групп для отправки в каждый день недели

# Создадим список с тегами групп
tags = [
    'cntrl_monday', 'cntrl_tuesday', 'cntrl_wednesday', 'cntrl_thursday',
    'cntrl_friday', 'cntrl_saturday', 'cntrl_sunday'
]

# Создаем колонку, куда будем записывать теги
ru_speaking['tag'] = ''

# В цикле итерируемся по списку и добавляем тег в соответствующую строку
num = 0
while num < len(ru_speaking):
    for tag in tags:
        ru_speaking.at[num, 'tag'] = tag
        num += 1

# %%
# Список контактов разделен на равные группы
ru_speaking['tag'].value_counts()


# %%
# Экспортируем каждую группу отдельно в эксель
for tag in tags:
    ru_speaking[ru_speaking['tag'] == tag].to_excel(f'control_test_samples/{tag}.xlsx')
