/**
 * Cloud Resume Challenge - Comptador de Visites
 * Projecte educatiu ASIX
 * 
 * Aquest script fa una crida a l'API Gateway per:
 * 1. Incrementar el comptador de visites a DynamoDB
 * 2. Mostrar el nombre total de visites al CV
 */

// Configuració de l'API
// IMPORTANT: Substitueix aquesta URL per l'endpoint real de la teva API Gateway
const API_ENDPOINT = 'https://lp39seelbf.execute-api.us-east-1.amazonaws.com/prod/visites';

/**
 * Funció principal que s'executa quan es carrega la pàgina
 * Fa una crida a l'API i actualitza el comptador a la interfície
 */
async function updateVisitorCounter() {
    const counterElement = document.getElementById('visit-counter');
    
    if (!counterElement) {
        console.error('Element del comptador no trobat');
        return;
    }

    try {
        // Fem una petició POST a l'API per incrementar el comptador
        const response = await fetch(API_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            // Podem enviar informació addicional si cal
            body: JSON.stringify({
                page: 'cv',
                timestamp: new Date().toISOString()
            })
        });

        // Comprovem si la resposta és correcta
        if (!response.ok) {
            throw new Error(`Error HTTP: ${response.status}`);
        }

        // Parsejem la resposta JSON
        const data = await response.json();
        
        // Actualitzem el comptador a la interfície
        if (data.visites !== undefined) {
            counterElement.textContent = formatNumber(data.visites);
            counterElement.classList.add('updated');
            
            // Eliminem la classe d'animació després de completar-la
            setTimeout(() => {
                counterElement.classList.remove('updated');
            }, 300);
        } else {
            counterElement.textContent = 'N/A';
        }

    } catch (error) {
        // En cas d'error, mostrem un missatge informatiu
        console.error('Error al actualitzar el comptador:', error);
        
        // Mostrem un valor per defecte o missatge d'error
        counterElement.textContent = '---';
        
        // Opcionalment, podem mostrar un missatge a la consola per debugging
        console.info('Consell: Comprova que l\'API Gateway està configurat correctament');
    }
}

/**
 * Funció auxiliar per formatar números grans
 * Exemple: 1234 -> "1.234"
 * @param {number} num - Número a formatar
 * @returns {string} - Número formatat
 */
function formatNumber(num) {
    return new Intl.NumberFormat('ca-ES').format(num);
}

/**
 * Funció alternativa per fer GET en lloc de POST
 * Útil per obtenir el comptador sense incrementar-lo
 */
async function getVisitorCount() {
    try {
        const response = await fetch(API_ENDPOINT, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
            }
        });

        if (!response.ok) {
            throw new Error(`Error HTTP: ${response.status}`);
        }

        const data = await response.json();
        return data.visites || 0;
        
    } catch (error) {
        console.error('Error al obtenir el comptador:', error);
        return null;
    }
}

// Executem la funció quan el DOM estigui completament carregat
document.addEventListener('DOMContentLoaded', () => {
    // Petit delay per assegurar que tot està carregat
    setTimeout(updateVisitorCounter, 100);
});

// Exportem les funcions per a testing (si s'utilitza amb mòduls)
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        updateVisitorCounter,
        getVisitorCount,
        formatNumber
    };
}
