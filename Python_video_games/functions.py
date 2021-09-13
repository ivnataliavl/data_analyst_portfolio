import pandas as pd


def visual_normality_check(feature_name: str, df_name: pd.DataFrame):
    '''
    Помогает визуально проверить на нормальность распределение количественных данных;
    На вход принимает датафрейм пандас и название колонки;
    В колонке данные должны иметь только один тип;
    Выводит гистограмму с fitted Gaussian normal distribution curve line;
    Выводит qq-plot
    :param feature_name: str
    :param df_name: pd.DataFrame
    '''
    # импортируем библиотеки
    from fitter import Fitter
    import statsmodels.api as sm
    import matplotlib.pyplot as plt

    # matplotlib params
    plt.rcParams.update({'font.size': 15})

    feature = df_name[feature_name]

    # hist plot with gaussian norm dist line
    f = Fitter(feature, distributions=['norm'])
    f.fit()
    f.summary()

    # qqplot
    sm.qqplot(feature, fit=True, line='s', label=f'QQ-plot for {feature_name}')
    plt.legend()
    plt.show()


def statistical_normality_test(feature_name: str, df_name: pd.DataFrame, alpha: float):
    """
    Статистически проверяет распределение количественных данных на нормальность;

    Input:
    Alpha для построение доверительного интервала4
    Датафрейм пандас и название колонки;
    В колонке данные должны иметь только один тип;

    Выводит результаты тестов на нормальность и их интерпретацию Shaporo-Wilk и D'Agostino's K^2;
    :param feature_name: str
    :param df_name: pd.DataFrame
    :param alpha: int
    """
    # импортируем библиотеки с тестами
    from scipy.stats import normaltest
    from scipy.stats import shapiro


    feature = df_name[feature_name]

    print(f'{feature_name} normality check \n')

    # Shaporo-wilk test
    sh_stat, sh_p = shapiro(feature)
    print(
        f'Shapiro-Wilk normality test for {feature_name}\n'
        f'Statistics={round(sh_stat,4)}, p-value={round(sh_p, 4)}% \n'
    )
    # shaporo-wilk test interpret
    if sh_p > alpha:
        print('Shapiro-Wilk: Sample looks Gaussian (fail to reject H0) \n')
    else:
        print('Shapiro-Wilk: Sample does not look Gaussian (can reject H0) \n')


    # D’Agostino’s K^2 Test
    d_stat, d_p = normaltest(feature)
    print(
        f'D’Agostino’s K^2 normality Test test for {feature_name}\n'
        f'Statistics={round(d_stat,4)}, p-value={round(d_p, 4)}% \n'
    )
    # D’Agostino’s K^2 Test interpret
    if d_p > alpha:
        print('D’Agostino’s: Sample looks Gaussian (fail to reject H0) \n')
    else:
        print('D’Agostino’s: Sample does not look Gaussian (can reject H0) \n')