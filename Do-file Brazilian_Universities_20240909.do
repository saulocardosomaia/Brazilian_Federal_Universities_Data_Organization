// processa os dados financeiros das universidades
clear all
//Cria a pasta IFES:
capture cd "C:\IFES"
if _rc!=0 {
shell mkdir "C:\IFES"
}
cd "C:\IFES"

/*Acesse os dados orçamentários atraves do seguinte link: https://www1.siop.planejamento.gov.br/QvAJAXZfc/opendoc.htm?document=IAS%2FExecucao_Orcamentaria.qvw&host=QVS%40pqlk04&anonymous=true&sheet=SH06 
Aba passo 1: selecionar consulta livre - selecionar os anos adotados na pesquisa - orgão orçamentário: 26000 Ministério da Educação 
Aba passo 2: marcar detalhar por unidade orçamentária
Aba passo 3: clica com o botão direito do mouse para exportar os dados
Salvar na pasta C:\IFES com o nome "orcamentos" (letra minuscula e sem cedilha)*/

import delimited "C:\IFES\orcamentos.csv", varnames(1) encoding(UTF-8) clear 
rename ano t
label variable t "Ano"
drop if t=="Total"
encode unidadeorçamentária,generate(ent)
gen id = substr(unidadeorçamentária,1,5)
drop unidadeorçamentária órgãoorçamentário
destring id, replace
label variable id "Código da entidade"
rename empenhado emp
rename liquidado liq
rename pago pag
order id ent t
drop projetodelei dotaçãoinicial dotaçãoatual
destring emp liq pag, replace ignore(`"."') dpcomma
gen date = yearly(t,"Y",2050)
drop t
rename date t
order id ent t
format t %ty
label variable t "Ano"
replace emp = round(emp)
replace liq = round(liq)
replace pag = round(pag)
xtset id t
xtdescribe
xtsum
gen tipo = 1
label variable tipo "Tipo de entidade"
replace tipo = 2 if id == 26256 | id == 26257 
replace tipo = 2 if id >= 26402 & id <= 26439
replace tipo = 3 if id >= 26290 & id <= 26298
replace tipo = 3 if id == 26443
replace tipo = 3 if id <= 26201
replace tipo = 3 if id >= 26358 & id <= 26401
replace tipo = 3 if id >= 26444 & id <= 26445
replace tipo = 3 if id == 26451

drop if tipo == 3 // apagar tipo 3, ou seja instituições que não são institutos e nem universidades 

gen dtipo = 0
replace dtipo = 1 if tipo == 2
label variable dtipo "Dummy Tipo, 0 para univesidades e 1 para institutos"
drop if id >= 26452 //retirando universidades muito novas, com dados apenas a partir de 2020. Comente essa linha se quiser incluir essa universidade. Identificar se há outras universidades novas a serem desconsideradas.

merge m:1 id using "C:\IFES\Dicionariocodigos.dta" //Disponibilizar em repositório público

label variable codies "Código da IES" // As universidades do Rio de janeiro e Rio Grande do Norte possuiam valores orçamentários em duas entidades sendo uma fundação e a respectiva universidade, cujos valores foram somados por meio da identificação dos códigos.

drop if _merge !=3
drop _merge

//Somando valores orçamentários das Universidades que possuiam valores orçamentários em duas entidades:
duplicates tag codies t , generate (tag)
sort codies t
egen emp2 = total(emp), by(codies t)
egen liq2 = total( liq ), by(codies t)
egen pag2 = total( pag ), by(codies t)
replace emp = emp2 if tag == 1
replace liq = liq2 if tag == 1
replace pag = pag2 if tag == 1
drop emp2 liq2 pag2 tag
duplicates drop codies t, force
save "C:\IFES\Orcamentos.dta", replace

//copy "https://download.inep.gov.br/microdados/microdados_censo_da_educacao_superior_2014.zip" 

//Faça o download dos arquivos anuais no seguinte endereço: https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados/censo-da-educacao-superior 
//Salve na pasta C:\IFES

//Descompacte todos os arquivos na pasta C:\IFES


clear all
tempfile master
save `master', replace empty
forvalues i=2014/2022 {
import delimited "C:\IFES\microdados_censo_da_educacao_superior_`i'\Microdados do Censo da Educação Superior `i'\dados\MICRODADOS_CADASTRO_CURSOS_`i'.CSV", clear
// Para o caminho na linha acima atentar-se a diferenças nos nomes dos arquivos, a partir do ano de 2022 a descrição do caminho do arquivo está diferente.
keep if tp_modalidade_ensino == 1
rename nu_ano_censo t
rename co_ies codies
order codies t
sort codies t
by codies  t, sort : egen float ncursos = count(in_gratuito)
by codies  t, sort : egen float nalu = total(qt_mat)
keep codies t ncursos nalu //descomentar caso deseje trabalhar com mais variáveis. O arquivo pode ficar demasiado grande portanto escolha criteriosamente as variáveis.
append using `master'
save `master', replace 
 } 
label variable ncursos "Quantidade de cursos"
label variable nalu "Quantidade de alunos"
label variable t "Ano"
label variable codies "Código da IES"
duplicates drop codies t, force
save "C:\IFES\Censocursos.dta", replace 


clear all
tempfile master
save `master', replace empty
forvalues i=2014/2022 {
import delimited "C:\IFES\microdados_censo_da_educacao_superior_`i'\Microdados do Censo da Educação Superior `i'\dados\MICRODADOS_CADASTRO_IES_`i'.CSV", clear
// Para o caminho na linha acima atentar-se a diferenças nos nomes dos arquivos, a partir do ano de 2022 a descrição do caminho do arquivo está diferente.
rename nu_ano_censo t
rename co_ies codies
gen nserv = qt_tec_total+qt_doc_total
keep if tp_categoria == 1
keep t codies nserv sg_ies no_mantenedora co_regiao_ies //descomentar caso deseje trabalhar com mais variáveis. O arquivo pode ficar demasiado grande portanto escolha criteriosamente as variáveis.
order codies t
sort codies t
append using `master'
save `master', replace 
 }
label variable t "Ano"
label variable codies "Código da IES"
label variable nserv "Número de servidores"
label variable co_regiao_ies "Região"
duplicates drop codies t, force
save "C:\IFES\Censoies.dta", replace 


//baixando dados macroeconomicos
*PIB (Variação percentual)
import delimited "https://api.bcb.gov.br/dados/serie/bcdata.sgs.7326/dados?formato=csv", delimiter(";") varnames (1) clear 
gen data2=date(data,"DMY")
format data2 %td
destring valor, replace float dpcomma
gen ano=year(data2)
rename ano t
rename valor pib
keep t pib
order t pib
keep if t > 2009
label variable pib "PIB - Taxa de variação real no ano"
save "C:\IFES\PIB.dta", replace 

*PIB (Pib em reais ajustado pela inflação)
import delimited "https://api.bcb.gov.br/dados/serie/bcdata.sgs.1211/dados?formato=csv", delimiter(";") varnames (1) clear 
gen data2=date(data,"DMY")
format data2 %td
destring valor, replace float dpcomma
gen ano=year(data2)
rename ano t
rename valor defla
keep t defla
order t defla
keep if t > 2009
label variable defla "Deflator do PIB"
save "C:\IFES\PIBdefla.dta", replace 

import delimited "https://api.bcb.gov.br/dados/serie/bcdata.sgs.1207/dados?formato=csv", delimiter(";") varnames (1) clear 
gen data2=date(data,"DMY")
format data2 %td
destring valor, replace float dpcomma
gen ano=year(data2)
rename ano t
rename valor pibnominal
keep t pibnominal
order t pibnominal
keep if t > 2009
label variable pibnominal "PIB nominal"
save "C:\IFES\PIBnominal.dta", replace 

merge 1:1 t using "C:\IFES\PIBdefla.dta", nogen
generate deflaindex = 100 if t == 2010
replace deflaindex = (defla/100+1)*deflaindex[_n-1] if t > 2010
replace deflaindex = round(deflaindex,0.000001)
generate pibadj = round( pibnominal *(deflaindex[_N]/deflaindex[_n]))
label variable pibadj "PIB ajustado pela inflação"
keep t pibadj
save "C:\IFES\PIBadj.dta", replace 


*PIB (Ln do PIB em dolar)
import delimited "https://api.bcb.gov.br/dados/serie/bcdata.sgs.4192/dados?formato=csv", delimiter(";") varnames (1) clear 
gen data2=date(data,"DMY")
format data2 %td
destring valor, replace dpcomma
gen mes=month(data2)
gen ano=year(data2)
keep if mes == 12
rename ano t
rename valor lnpib
keep t lnpib
order t lnpib
label variable lnpib "Ln PIB 12 meses em Dólares"
replace lnpib = round(ln(lnpib),0.01)
keep if t > 2009
save "C:\IFES\LnPIB.dta", replace 

*IGPM
import delimited "https://api.bcb.gov.br/dados/serie/bcdata.sgs.28655/dados?formato=csv", delimiter(";") varnames (1) clear
gen data2=date(data,"DMY")
format data2 %td
destring valor, replace dpcomma
rename valor igpm
label variable igpm "IGP-M variação % mensal"
drop if data2<12631
generate igpmindex = 100 if data2 == 12631
replace igpmindex = (igpm/100+1)*igpmindex[_n-1] if igpmindex > 12631
replace igpmindex = round(igpmindex,0.000001)
label variable igpmindex "Índice IGP-M agosto/1994 = 100"
gen mes=month(data2)
gen ano=year(data2)
keep if mes == 12
rename ano t
keep t igpmindex
order t igpmindex
keep if t > 2009
save "C:\IFES\IGPM.dta", replace 

*Selic
import delimited "https://api.bcb.gov.br/dados/serie/bcdata.sgs.432/dados?formato=csv", delimiter(";") varnames (1) clear 
gen data2=date(data,"DMY")
format data2 %td
destring valor, replace float dpcomma
gen ano=year(data2)
rename ano t
rename valor selicdia
keep t selicdia
order t selicdia
bysort t: egen selic = mean(selicdia)
drop selicdia
duplicates drop t, force
keep if t > 2009
label variable selic "Taxa Selic"
save "C:\IFES\Selic.dta", replace 

*IPCA
import delimited "https://api.bcb.gov.br/dados/serie/bcdata.sgs.433/dados?formato=csv", delimiter(";") varnames (1) clear
gen data2=date(data,"DMY")
format data2 %td
destring valor, replace dpcomma
rename valor ipca
label variable ipca "IPCA variação % mensal"
drop if data2<12631
generate ipcaindex = 100 if data2 == 12631
replace ipcaindex = (ipca/100+1)*ipcaindex[_n-1] if ipcaindex > 12631
replace ipcaindex = round(ipcaindex,0.000001)
label variable ipcaindex "Índice IPCA agosto/1994 = 100"
gen mes=month(data2)
gen ano=year(data2)
keep if mes == 12
rename ano t
keep t ipcaindex
order t ipcaindex
keep if t > 2009
save "C:\IFES\IPCA.dta", replace 


merge 1:1 t using "C:\IFES\PIB.dta", nogen
merge 1:1 t using "C:\IFES\LnPIB.dta", nogen
merge 1:1 t using "C:\IFES\IGPM.dta", nogen
merge 1:1 t using "C:\IFES\Selic.dta", nogen
merge 1:1 t using "C:\IFES\PIBadj.dta", nogen
tsset t


save "C:\IFES\macroeco.dta", replace
tsline igpmindex ipcaindex, scale(0.6) name(igpmindex, replace)
graph export "C:\IFES\Tsline Inflacao.pdf", as(pdf) replace

//Para fazer o download das emendas parlamentares acessar o link: https://portaldatransparencia.gov.br/download-de-dados/emendas-parlamentares/UNICO
//baixar o arquivo e salvar na pasta IFES.
cd "C:\IFES"
unzipfile emendasparlamentares.zip, replace
import delimited "C:\IFES\emendas", clear
destring valorliquidado, generate(emendas) dpcomma
rename anodaemenda t
keep t emendas
bysort t: egen emen = total(emendas)
duplicates drop t, force
replace emen=emen/1000000
label variable emen "Emendas parlamentares (em R$ milhões)"
save "C:\IFES\Emendas.dta", replace

use "C:\IFES\Orcamentos.dta", clear	//fazendo a fusão entre os dados do orçamento e do censo da educação superior - inep
	
merge 1:1 codies t using "C:\IFES\Censoies.dta"
drop if _merge !=3
drop _merge
order id codies
merge 1:1 codies t using "C:\IFES\Censocursos.dta"
drop if _merge !=3
drop _merge
label variable nserv "Quantidade de servidores"


merge m:1 t using "C:\IFES\macroeco.dta" //importando os dados macroeconomicos
drop if _merge !=3
drop _merge

merge m:1 t using "C:\IFES\emendas" //importando os dados das emendas parlamentares
drop if _merge !=3
drop _merge

gen EC95 = 0
replace EC95 = 1 if t>2017
label variable EC95 "Emenda Constitucional 95"

gen dtipoEC95 = dtipo * EC95 
label variable dtipoEC95 "Dummy interativa tipo e EC95"

gen dtipoemen = dtipo * emen
label variable dtipoemen "Dummy interativa tipo e emendas parlamentares"

rename sg_ies sigla
label variable sigla "Sigla"
rename no_mantenedora nome
label variable nome "Nome"
replace sigla = "UFSB" if sigla == "UFESBA"
replace sigla = "IFTM" if codies == 3165
rename emp empnominal
rename liq liqnominal
rename pag pagnominal
label variable empnominal "Despesa empenhada sem correção"
label variable liqnominal "Despesa liquidada sem correção"
label variable pagnominal "Despesa paga sem correção"
/*by id (t), sort: generate liq = round( liqnominal *(ipcaindex[_N]/ipcaindex[_n]))
by id (t), sort: generate emp = round( empnominal *(ipcaindex[_N]/ipcaindex[_n]))
by id (t), sort: generate pag = round( pagnominal *(ipcaindex[_N]/ipcaindex[_n]))*/
by id (t), sort: generate liq = round( liqnominal *(igpmindex[_N]/igpmindex[_n]))
by id (t), sort: generate emp = round( empnominal *(igpmindex[_N]/igpmindex[_n]))
by id (t), sort: generate pag = round( pagnominal *(igpmindex[_N]/igpmindex[_n]))
label variable liq "Despesa liquidada (em R$ milhões)"
label variable emp "Despesa empenhada"
label variable pag "Despesa paga"


/* gerar dummy regional*/ // Caso o pesquisador deseje analisar por região
gen d1 =0
replace d1 = 1 if co_regiao_ies == 1
label variable d1 "Região Norte"

gen d2 =0
replace d2 = 1 if co_regiao_ies == 2
label variable d2 "Região Nordeste"

gen d3 =0
replace d3 = 1 if co_regiao_ies == 3
label variable d3 "Região Sudeste"

gen d4 =0
replace d4 = 1 if co_regiao_ies == 4
label variable d4 "Região Sul"

gen d5 =0
replace d5 = 1 if co_regiao_ies == 5
label variable d5 "Região Centro-Oeste"

gen dec95se = 0
gen aec95su = 0
gen dec95su = 0
gen aec95no = 0
gen dec95no = 0
gen aec95ne = 0
gen dec95ne = 0
gen aec95co = 0
gen dec95co = 0

label variable dec95se "Região Sudeste depois da EC95"
label variable dec95su "Região Sul depois da EC95"
label variable dec95no "Região Norte depois da EC95"
label variable dec95ne "Região Nordeste depois da EC95"
label variable dec95co "Região Centro-Oeste depois da EC95"
label variable aec95no "Região Norte antes da EC95"
label variable aec95ne "Região Nordeste antes da EC95"
label variable aec95su "Região Sul antes da EC95"
label variable aec95co "Região Centro-Oeste antes da EC95"

replace dec95se = 1 if d3 == 1 & EC95 == 1
replace dec95su = 1 if d4 == 1 & EC95 == 1
replace dec95no = 1 if d1 == 1 & EC95 == 1
replace dec95ne = 1 if d2 == 1 & EC95 == 1
replace dec95co = 1 if d5 == 1 & EC95 == 1

replace aec95no = 1 if d1 == 1 & EC95 == 0
replace aec95ne = 1 if d2 == 1 & EC95 == 0
replace aec95su = 1 if d4 == 1 & EC95 == 0
replace aec95co = 1 if d5 == 1 & EC95 == 0

save "C:\IFES\Dadosfinais.dta", replace

/* Análises - Universidades*/
xtdescribe if tipo == 1
replace liq = liq/1000000
tabstat liq ncur nalu nserv pib selic emen if tipo == 1, statistics(count min max median mean sd cv) columns(statistics)


histogram liq if tipo == 1, percent 
graph export "C:\IFES\histogramauniversidades.pdf", as(pdf) name("Graph") replace


*graph hbox liq descomentar para gráfico horizontal
graph box liq, by(EC95)
graph box liq if tipo == 1, by(EC95)
graph export "C:\IFES\boxplotuniversidades.pdf", as(pdf) name("Graph") replace


label variable sigla "Universidade"
twoway (tsline liq) if tipo==1, ytitle(, size(vsmall)) ylabel(, labsize(vsmall)) ttitle(, size(zero)) tlabel(, labsize(vsmall)) by(sigla, note(""))
graph export "C:\IFES\gráfico evolução liquidadas.pdf", as(pdf) name("Graph") replace


graph matrix liq nalu ncursos nserv if tipo==1, msize(vsmall) msymbol(smcircle)
graph export "C:\IFES\grafico de dispersão  das variaveis.pdf", as(pdf) name("Graph") replace

pwcorr liq nserv nalu ncursos emen pib if tipo==1, star(0.01)

/* análise de multicolineariedade */
regress liq nalu nserv ncursos pib selic emen if tipo == 1
estat vif
regress nserv nalu ncursos pib selic emen if tipo == 1 
regress ncursos nalu pib selic nserv emen if tipo == 1 
regress nalu ncursos pib selic nserv emen if tipo == 1
regress pib selic nserv nalu ncursos emen if tipo == 1
regress emen nserv ncursos nalu pib selic if tipo == 1

/* passo 1 - modelo pooled*/
regress liq EC95 emen nserv ncursos pib selic if tipo == 1

/* passo 2 - modelos de efeitos fixos */
xtreg liq EC95 emen nserv ncursos pib selic if tipo == 1, fe

/* passo 3 - f que consta no passo 2*/

/* passo 4 - modelo de efeitos aleatorios */
xtreg liq EC95 emen nserv ncursos pib selic if tipo == 1, re

/* passo 5 -  teste de Breusch-Pagan */
xttest0

/* passo 6 - teste de Hausman */ //Descomentar se os modelos fixos e aleatorios forem iguais
quietly xtreg liq EC95 emen nserv ncursos pib selic if tipo == 1, fe
estimates store fixed
quietly xtreg liq EC95 emen nserv ncursos pib selic if tipo == 1, re
estimates store random
hausman fixed random, sigmamore

/* passo 7 - teste de Wooldrigde */
xtserial liq EC95 emen nserv ncursos pib selic if tipo == 1

/* passo 8 - teste de Wald */
quietly xtreg liq EC95 emen nserv ncursos pib selic if tipo == 1, fe
xttest3

/* passo 9 - modelo robusto clusterizado */
xtreg liq EC95 emen nserv ncursos pib selic if tipo == 1, fe vce(robust)



/* Análises - Institutos*/
xtdescribe if tipo == 2
tabstat liq ncur nalu nserv pib selic emen if tipo == 2, statistics(count min max median mean sd cv) columns(statistics)


histogram liq if tipo == 2, percent 
graph export "C:\IFES\histogramauniversidades.pdf", as(pdf) name("Graph") replace


*graph hbox liq descomentar para gráfico horizontal
graph box liq, by(EC95)
graph box liq if tipo == 2, by(EC95)
graph export "C:\IFES\boxplotuniversidades.pdf", as(pdf) name("Graph") replace


label variable sigla "Universidade"
twoway (tsline liq) if tipo==2, ytitle(, size(vsmall)) ylabel(, labsize(vsmall)) ttitle(, size(zero)) tlabel(, labsize(vsmall)) by(sigla, note(""))
graph export "C:\IFES\gráfico evolução liquidadas institutos.pdf", as(pdf) name("Graph") replace


graph matrix liq nalu ncursos nserv if tipo==2, msize(vsmall) msymbol(smcircle)
graph export "C:\IFES\grafico de dispersão  das variaveis institutos.pdf", as(pdf) name("Graph") replace

pwcorr liq nserv nalu ncursos emen pib if tipo==1, star(0.01)

/* análise de multicolineariedade */
regress liq nalu nserv ncursos pib selic emen if tipo == 2
estat vif
regress nserv nalu ncursos pib selic emen if tipo == 2 
regress ncursos nalu pib selic nserv emen if tipo == 2 
regress nalu ncursos pib selic nserv emen if tipo == 2
regress pib selic nserv nalu ncursos emen if tipo == 2
regress emen nserv ncursos nalu pib selic if tipo == 2

/* passo 1 - modelo pooled*/
regress liq EC95 emen nserv pib selic if tipo == 2

/* passo 2 - modelos de efeitos fixos */
xtreg liq EC95 emen nserv pib selic if tipo == 2, fe

/* passo 3 - f que consta no passo 2*/

/* passo 4 - modelo de efeitos aleatorios */
xtreg liq EC95 emen nserv pib selic if tipo == 2, re

/* passo 5 -  teste de Breusch-Pagan */
xttest0

/* passo 6 - teste de Hausman */ //Descomentar se os modelos fixos e aleatorios forem iguais
quietly xtreg liq EC95 emen nserv pib selic if tipo == 2, fe
estimates store fixed
quietly xtreg liq EC95 emen nserv pib selic if tipo == 2, re
estimates store random
hausman fixed random, sigmamore

/* passo 7 - teste de Wooldrigde */
xtserial liq EC95 emen nserv pib selic if tipo == 2

/* passo 8 - teste de Wald */
quietly xtreg liq EC95 emen nserv pib selic if tipo == 2, fe
xttest3

/* passo 9 - modelo robusto clusterizado */
xtreg liq EC95 emen nserv pib selic if tipo == 2, fe vce(robust)


