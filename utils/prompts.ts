import inquirer from 'inquirer'

/**
 * Prompts for confirmation or exits the program if the user does not confirm.
 */
export async function promptForConfirmationOrExit() {
    const { shouldContinue } = await inquirer.prompt([
        {
            type: 'confirm',
            name: 'shouldContinue',
            message: 'Are you sure you want to continue?',
            default: false,
        },
    ])
    if (!shouldContinue) {
        console.log('❌ Operation cancelled.')
        process.exit(1)
    }
}
